#!/sbin/sh

module_dir="/data/adb/modules/box4"

[ -n "$(magisk -v | grep lite)" ] && module_dir=/data/adb/lite_modules/box4

scripts_dir="/data/adb/box/scripts"

(
until [ $(getprop sys.boot_completed) -eq 1 ] ; do
  sleep 3
done
${scripts_dir}/start.sh
)&

inotifyd ${scripts_dir}/box.inotify ${module_dir} > /dev/null 2>&1 &

while [ ! -f /data/misc/net/rt_tables ] ; do
  sleep 3
done

net_dir="/data/misc/net"
# 使用 inotifyd 监听 /data/misc/net 目录的写入事件以捕获网络变化，
# 也许我们有更好的监控目标文件（/proc 文件系统不受支持），而循环轮询不是好的方案
inotifyd ${scripts_dir}/net.inotify ${net_dir} > /dev/null 2>&1 &