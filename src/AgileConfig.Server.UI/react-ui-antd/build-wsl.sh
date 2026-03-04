#!/bin/bash

# Build the project
npm run build:ssl-legacy

# Define target directory
TARGET_DIR="/mnt/c/Users/Administrator/source/repos/AgileConfig/src/AgileConfig.Server.Apisite/bin/Debug/net10.0/wwwroot/ui"

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Copy dist contents to target
cp -rf dist/* "$TARGET_DIR/"

echo "Build completed and files copied to $TARGET_DIR"

echo "发布前输入服务器密码："
scp -r /mnt/c/Users/Administrator/source/repos/AgileConfig/src/AgileConfig.Server.Apisite/bin/Debug/net10.0/wwwroot/ui ak@192.168.205.134:/home/ak/www/ConfigCenter/wwwroot/
echo "复制并发布完成！"