<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { exec, spawn } from 'kernelsu'

// 定义运行状态枚举
enum RunStatus {
  Running = '运行中',
  Stopped = '已停止',
  Error = '错误',
  Unknown = '未知',
}
// 定义核心类型
enum CoreType {
  SingBox = 'sing-box',
  Xray = 'xray',
  Mihomon = 'mihomo',
  Hysteria = 'hysteria',
  Unknown = '未知',
}

// 定义 box4 数据目录
const boxDir = '/data/adb/box'
// 响应式变量
const coreType = ref<string>(CoreType.Unknown)
const runStatus = ref<RunStatus>(RunStatus.Unknown)
const subscription = ref<string>('')
const subscriptionInput = ref<string>('')

// 日志框变量
const controlLog = ref<string>('')
const subscriptionLog = ref<string>('')

// 控制函数
const startCode = async (): Promise<void> => {
  console.log('现在启动核心')
  // 清空之前的日志
  controlLog.value = ''

  const process = spawn(`${boxDir}/scripts/box.service start`)

  process.stdout.on('data', (data: string) => {
    controlLog.value += data.toString()
  })

  process.stderr.on('data', (data: string) => {
    controlLog.value += data.toString()
  })

  process.on('exit', (code: number) => {
    if (code === 0) {
      console.log('核心启动成功')
      // 更新运行状态
      getRunStatus().then((status) => {
        runStatus.value = status
      })
    } else {
      console.error(`启动失败，退出码: ${code}`)
    }
  })
}

const stopCore = async (): Promise<void> => {
  console.log('现在停止核心')
  // 清空之前的日志
  controlLog.value = ''

  const process = spawn(`${boxDir}/scripts/box.service stop`)

  process.stdout.on('data', (data: string) => {
    controlLog.value += data.toString()
  })

  process.stderr.on('data', (data: string) => {
    controlLog.value += data.toString()
  })

  process.on('exit', (code: number) => {
    if (code === 0) {
      console.log('核心停止成功')
      // 更新运行状态
      getRunStatus().then((status) => {
        runStatus.value = status
      })
    } else {
      console.error(`停止失败，退出码: ${code}`)
    }
  })
}

const restartCore = async (): Promise<void> => {
  console.log('现在重启核心')
  // 清空之前的日志
  controlLog.value = ''

  const process = spawn(`${boxDir}/scripts/box.service restart`)

  process.stdout.on('data', (data: string) => {
    console.log('[重启核心]: 有新的 stdout', data)
    controlLog.value += data.toString()
  })

  process.stderr.on('data', (data: string) => {
    console.error('[重启核心]: 有新的 stderr', data)
    controlLog.value += data.toString()
  })

  process.on('exit', (code: number) => {
    if (code === 0) {
      console.log('核心重启成功')
      // 更新运行状态
      getRunStatus().then((status) => {
        runStatus.value = status
      })
    } else {
      console.error(`重启失败，退出码: ${code}`)
    }
  })
}

const updateSubscription = async (): Promise<void> => {
  console.log('现在更新订阅')
  // 清空之前的日志
  subscriptionLog.value = ''

  // 从 subs.txt 读取订阅 URL
  const subsUrl = await getSubscription()
  if (subsUrl && subsUrl.trim() !== '') {
    // 根据核心类型确定配置文件路径
    let configPath: string
    switch (coreType.value) {
      case CoreType.SingBox:
        configPath = `${boxDir}/sing-box/config.json`
        break
      case CoreType.Xray:
        configPath = `${boxDir}/xray/config.json`
        break
      case CoreType.Mihomon:
        configPath = `${boxDir}/mihomo/config.yaml`
        break
      case CoreType.Hysteria:
        configPath = `${boxDir}/hysteria/config.yaml`
        break
      default:
        // 对于不支持的类型，记录错误日志
        subscriptionLog.value += `不支持的核心类型: ${coreType.value}\n`
        return
    }

    // 执行 curl 命令获取订阅内容并直接覆盖配置文件
    const process = spawn(`curl -s -H "User-Agent: Box4Android" -L "${subsUrl}" > "${configPath}"`)

    process.stdout.on('data', (data: string) => {
      console.log('[更新订阅]: 有新的 stdout', data)
      subscriptionLog.value += data.toString()
    })

    process.stderr.on('data', (data: string) => {
      console.error('[更新订阅]: 有新的 stderr', data)
      subscriptionLog.value += data.toString()
    })

    process.on('exit', (code: number) => {
      if (code === 0) {
        console.log('订阅更新成功')
        subscriptionLog.value += `订阅更新成功，已保存到: ${configPath}\n`
      } else {
        console.error(`更新订阅失败，退出码: ${code}`)
        subscriptionLog.value += `更新订阅失败，退出码: ${code}\n`
      }
    })
  } else {
    subscriptionLog.value += '订阅 URL 为空，无法更新\n'
  }
}

const saveSubscription = async (): Promise<void> => {
  console.log('现在保存订阅地址')
  // 清空之前的日志
  subscriptionLog.value = ''

  // 对用户输入的内容进行转义处理，防止特殊符号导致问题
  const escapedUrl = subscriptionInput.value.replace(/(["'$`\\])/g, '\\$1')
  // 把用户输入内容写入到 subs.txt
  const { errno, stderr } = await exec(`echo "${escapedUrl}" > ${boxDir}/scripts/subs.txt`)
  if (errno === 0) {
    // 更新订阅显示
    subscription.value = subscriptionInput.value
  } else {
    console.error(`保存订阅失败: ${stderr}`)
    subscriptionLog.value += `保存订阅失败: ${stderr}\n`
  }
}

const getCoreType = async (): Promise<string> => {
  console.log('获取核心类型')
  const { errno, stdout, stderr } = await exec(
    `cat ${boxDir}/scripts/box.config | grep bin_name= | cut -d '"' -f 2`,
  )
  if (errno === 0) {
    // return `version: ${stdout.split('version=')[1].split('\n')[0]`;
    return stdout.toString().trim()
  } else {
    return `Error executing command: ${stderr}`
  }
}

const getRunStatus = async (): Promise<RunStatus> => {
  console.log('获取运行状态')
  const { errno, stdout, stderr } = await exec(`${boxDir}/scripts/box.service status`)
  const output = stdout.toString().trim()
  const errout = stderr.toString().trim()
  switch (errno) {
    case 0:
      // 解析 stdout，检查是否包含 "is running" 或 "is stopped"
      // 先把 output 推到日志
      console.log('[获取运行状态]', output)
      controlLog.value = output
      if (output.includes('running')) {
        return RunStatus.Running
      } else if (output.includes('service is stopped')) {
        return RunStatus.Stopped
      } else {
        return RunStatus.Error
      }
    case 1:
      if (output.includes('service is stopped')) {
        controlLog.value = errout
        return RunStatus.Stopped
      }
    default:
      return RunStatus.Error
  }
}

const getSubscription = async (): Promise<string> => {
  console.log('获取订阅地址')
  const { errno, stdout, stderr } = await exec(`cat ${boxDir}/scripts/subs.txt`)
  if (errno === 0) {
    return stdout.toString().trim()
  } else {
    return `Error executing command: ${stderr}`
  }
}

onMounted(async () => {
  // TODO: 实现初始化逻辑
  coreType.value = await getCoreType()
  runStatus.value = await getRunStatus()
  subscription.value = await getSubscription()
})
</script>

<template>
  <div class="app">
    <header class="app-header">
      <h1>box4magisk</h1>
    </header>

    <main class="app-main">
      <!-- 状态信息区域 -->
      <section class="status-section">
        <h2>核心状态</h2>
        <div class="status-grid">
          <div class="status-item">
            <label>核心类型:</label>
            <span>{{ coreType }}</span>
          </div>
          <div class="status-item">
            <label>运行状态:</label>
            <span>{{ runStatus }}</span>
          </div>
        </div>
      </section>

      <!-- 控制按钮区域 -->
      <section class="control-section">
        <h2>核心控制</h2>
        <div class="button-group">
          <button @click="startCode" class="btn btn-start">启动</button>
          <button @click="stopCore" class="btn btn-stop">停止</button>
          <button @click="restartCore" class="btn btn-restart">重启</button>
        </div>

        <!-- 控制日志框 -->
        <div class="log-section">
          <h3>控制日志</h3>
          <div class="log-container">
            <pre class="log-content">{{ controlLog }}</pre>
          </div>
        </div>
      </section>

      <!-- 订阅管理区域 -->
      <section class="subscription-section">
        <h2>订阅管理</h2>
        <div class="subscription-content">
          <div class="subscription-item">
            <label>已经保存的订阅地址:</label>
            <span>{{ subscription }}</span>
          </div>
          <div class="subscription-input">
            <input v-model="subscriptionInput" type="text" placeholder="请输入订阅地址" />
          </div>
          <div class="button-group">
            <button @click="updateSubscription" class="btn btn-update">更新订阅</button>
            <button @click="saveSubscription" class="btn btn-update">保存订阅地址</button>
          </div>
        </div>

        <!-- 订阅日志框 -->
        <div class="log-section">
          <h3>订阅日志</h3>
          <div class="log-container">
            <pre class="log-content">{{ subscriptionLog }}</pre>
          </div>
        </div>
      </section>
    </main>
  </div>
</template>

<style scoped>
.app {
  min-height: 100vh;
  background-color: var(--color-background);
  color: var(--color-text);
}

.app-header {
  background-color: var(--color-header);
  padding: 1rem 2rem;
  border-bottom: 1px solid var(--color-border);
}

.app-header h1 {
  margin: 0;
  font-size: 1.5rem;
  font-weight: 600;
}

.app-main {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
}

.status-section,
.control-section,
.subscription-section {
  margin-bottom: 2rem;
  padding: 1.5rem;
  background-color: var(--color-card);
  border-radius: 8px;
  border: 1px solid var(--color-border);
}

.status-section h2,
.control-section h2,
.subscription-section h2 {
  margin: 0 0 1rem 0;
  font-size: 1.25rem;
  font-weight: 500;
  color: var(--color-heading);
}

.status-grid {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.status-item {
  display: flex;
  flex-direction: row;
  gap: 0.5rem;
}

.status-item label {
  font-weight: 500;
  color: var(--color-text-muted);
}

.status-item span {
  font-size: 1.1rem;
  font-weight: 600;
}

.subscription-content {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.subscription-item {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.subscription-item label {
  font-weight: 500;
  color: var(--color-text-muted);
}

.subscription-item span {
  font-family: monospace;
  background-color: var(--color-code-bg);
  padding: 0.5rem;
  border-radius: 4px;
  border: 1px solid var(--color-border);
  min-height: 1.2rem;
  word-break: break-all;
}

.button-group {
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
}

.btn {
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 6px;
  font-size: 1rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
  min-width: 100px;
}

.btn-start {
  background-color: #10b981;
  color: white;
}

.btn-start:hover {
  background-color: #059669;
}

.btn-stop {
  background-color: #ef4444;
  color: white;
}

.btn-stop:hover {
  background-color: #dc2626;
}

.btn-restart {
  background-color: #f59e0b;
  color: white;
}

.btn-restart:hover {
  background-color: #d97706;
}

.btn-update {
  background-color: #3b82f6;
  color: white;
}

.btn-update:hover {
  background-color: #2563eb;
}

.log-section {
  margin-top: 1rem;
}

.log-section h3 {
  margin: 0 0 0.5rem 0;
  font-size: 1.1rem;
  font-weight: 500;
  color: var(--color-heading);
}

.log-container {
  background-color: var(--color-code-bg);
  border: 1px solid var(--color-border);
  border-radius: 4px;
  padding: 0.5rem;
  max-height: 200px;
  overflow-y: auto;
}

.log-content {
  margin: 0;
  font-family: monospace;
  font-size: 0.9rem;
  white-space: pre-wrap;
  word-break: break-all;
}

.subscription-input input {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid var(--color-border);
  border-radius: 4px;
  font-family: monospace;
}

@media (max-width: 768px) {
  .app-main {
    padding: 1rem;
  }

  .status-section,
  .control-section,
  .subscription-section {
    padding: 1rem;
  }

  .button-group {
    flex-direction: column;
  }

  .btn {
    width: 100%;
  }
}
</style>
