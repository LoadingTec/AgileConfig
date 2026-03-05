#!/bin/bash
# AgileConfig Server - Ubuntu 部署/更新脚本
# 在已安装 AgileConfig 服务的 Ubuntu 上更新应用文件
# 用法:
#   方式1 - 在项目目录执行: bash deploy-ubuntu.sh [--deploy-dir /opt/agileconfig]
#   方式2 - 远程部署: bash deploy-ubuntu.sh --remote user@host [--deploy-dir /opt/agileconfig]

set -e

DEPLOY_DIR="/opt/agileconfig"
REMOTE_TARGET=""
RESTART_SERVICE=true
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLISH_DIR="/tmp/agileconfig-deploy-$$"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --deploy-dir) DEPLOY_DIR="$2"; shift 2 ;;
        --remote) REMOTE_TARGET="$2"; shift 2 ;;
        --no-restart) RESTART_SERVICE=false; shift ;;
        *) echo "未知选项: $1"; exit 1 ;;
    esac
done

echo "=========================================="
echo "  AgileConfig Server - 部署脚本"
echo "=========================================="

# 本地发布
do_publish() {
    echo "[1] 发布项目..."
    cd "$PROJECT_ROOT"
    dotnet publish AgileConfig.Server.Apisite.csproj -c Release -o "$PUBLISH_DIR"
}

# 本地部署
do_local_deploy() {
    if [[ $EUID -ne 0 ]]; then
        echo "本地部署需要 root 权限，请使用 sudo"
        exit 1
    fi
    echo "[2] 停止服务..."
    systemctl stop agileconfig.service 2>/dev/null || true
    echo "[3] 备份并复制文件..."
    if [[ -d "$DEPLOY_DIR" ]]; then
        # 备份 appsettings.json、appsettings.*.json、logs、agile_config.db 等
        mkdir -p /tmp/agileconfig-backup
        cp -p "$DEPLOY_DIR/appsettings.json" /tmp/agileconfig-backup/ 2>/dev/null || true
        cp -p "$DEPLOY_DIR/appsettings.Production.json" /tmp/agileconfig-backup/ 2>/dev/null || true
        cp -p "$DEPLOY_DIR/agile_config.db" /tmp/agileconfig-backup/ 2>/dev/null || true
    fi
    mkdir -p "$DEPLOY_DIR"
    rsync -av --exclude='appsettings*.json' --exclude='agile_config.db' --exclude='logs' \
        "$PUBLISH_DIR/" "$DEPLOY_DIR/"
    # 恢复配置文件
    cp -p /tmp/agileconfig-backup/appsettings.json "$DEPLOY_DIR/" 2>/dev/null || true
    cp -p /tmp/agileconfig-backup/appsettings.Production.json "$DEPLOY_DIR/" 2>/dev/null || true
    cp -p /tmp/agileconfig-backup/agile_config.db "$DEPLOY_DIR/" 2>/dev/null || true
    rm -rf /tmp/agileconfig-backup
    if [[ "$RESTART_SERVICE" == "true" ]]; then
        echo "[4] 启动服务..."
        systemctl start agileconfig.service
        systemctl status agileconfig.service --no-pager
    fi
}

# 远程部署
do_remote_deploy() {
    echo "[2] 打包发布文件..."
    tar czf /tmp/agileconfig-deploy.tar.gz -C "$PUBLISH_DIR" .
    echo "[3] 上传到 $REMOTE_TARGET ..."
    scp /tmp/agileconfig-deploy.tar.gz "$REMOTE_TARGET:/tmp/"
    echo "[4] 在远程主机执行部署..."
    ssh "$REMOTE_TARGET" "sudo bash -s" -- "$DEPLOY_DIR" "$RESTART_SERVICE" << 'REMOTE_SCRIPT'
DEPLOY_DIR="${1:-/opt/agileconfig}"
RESTART="${2:-true}"
mkdir -p "$DEPLOY_DIR"
# 备份配置与数据
cp -p "$DEPLOY_DIR/appsettings.json" /tmp/ 2>/dev/null || true
cp -p "$DEPLOY_DIR/appsettings.Production.json" /tmp/ 2>/dev/null || true
cp -p "$DEPLOY_DIR/agile_config.db" /tmp/ 2>/dev/null || true
# 解压并覆盖（保留 logs 目录）
cd /tmp && tar xzf agileconfig-deploy.tar.gz -C "$DEPLOY_DIR"
cp -p /tmp/appsettings.json "$DEPLOY_DIR/" 2>/dev/null || true
cp -p /tmp/appsettings.Production.json "$DEPLOY_DIR/" 2>/dev/null || true
cp -p /tmp/agile_config.db "$DEPLOY_DIR/" 2>/dev/null || true
rm -f agileconfig-deploy.tar.gz
if [[ "$RESTART" == "true" ]]; then
    systemctl restart agileconfig.service
    echo "服务已重启"
fi
REMOTE_SCRIPT
    rm -f /tmp/agileconfig-deploy.tar.gz
}

# 主流程
do_publish
if [[ -n "$REMOTE_TARGET" ]]; then
    do_remote_deploy
else
    do_local_deploy
fi
rm -rf "$PUBLISH_DIR"
echo ""
echo "部署完成！"
