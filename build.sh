#!/bin/sh

# 获取版本号
VERSION=$(cat module.prop | grep 'version=' | awk -F '=' '{print $2}')

# 如果文件存在则删除
if [ -f "box4_${VERSION}.zip" ]; then
    rm "box4_${VERSION}.zip"
fi
# 使用 git ls-files 获取所有被跟踪的文件（自动排除 .gitignore 中的文件）
# 然后添加额外的排除项
git ls-files | grep -v -E '^(webui|\.git|\.github|box4\.json|bun|package\.json|node_modules|build.sh|gitkeep)' | \
xargs zip -r -o -X -ll "box4_${VERSION}.zip"

# 单独添加 webroot 目录到 zip
if [ -d "webroot" ]; then
    echo "Adding webroot directory..."
    zip -r -o -X -ll "box4_${VERSION}.zip" webroot
fi

# 添加动态下载的 mihomo 核心到 zip（工作流中下载的二进制文件）
if [ -f "box/bin/mihomo" ]; then
    echo "Adding mihomo binary..."
    zip -o -X "box4_${VERSION}.zip" box/bin/mihomo
fi