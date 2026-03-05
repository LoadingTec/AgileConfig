#!/bin/bash
# AgileConfig Server - Ubuntu 服务一键安装脚本
# 用于在 Ubuntu 上安装 .NET 运行时、创建服务用户、部署应用并配置 systemd 服务
# 用法: sudo bash install-ubuntu.sh [OPTIONS]
#
# 选项:
#   --deploy-dir DIR    部署目录，默认 /opt/agileconfig
#   --user USER         服务运行用户，默认 agileconfig
#   --port PORT         监听端口，默认 5000
#   --self-contained    使用自包含发布（不依赖系统 .NET 运行时）

set -e

# 默认配置
DEPLOY_DIR="/opt/agileconfig"
SERVICE_USER="agileconfig"
SERVICE_GROUP="agileconfig"
PORT=5000
SELF_CONTAINED=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 脚本位于 AgileConfig.Server.Apisite/deploy/，上一级即为项目目录
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --deploy-dir) DEPLOY_DIR="$2"; shift 2 ;;
        --user) SERVICE_USER="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        --self-contained) SELF_CONTAINED=true; shift ;;
        *) echo "未知选项: $1"; exit 1 ;;
    esac
done

echo "=========================================="
echo "  AgileConfig Server - Ubuntu 安装脚本"
echo "=========================================="
echo "  部署目录: $DEPLOY_DIR"
echo "  运行用户: $SERVICE_USER"
echo "  监听端口: $PORT"
echo "  自包含模式: $SELF_CONTAINED"
echo "=========================================="

# 检测是否为 root
if [[ $EUID -ne 0 ]]; then
    echo "错误: 请使用 sudo 运行此脚本"
    exit 1
fi

# 1. 安装 .NET 运行时（项目使用 net10.0，建议用 --self-contained；否则需先安装 .NET 10）
if [[ "$SELF_CONTAINED" != "true" ]]; then
    echo "[1/6] 检查 .NET 运行时..."
    if ! command -v dotnet &> /dev/null; then
        echo "错误: 未检测到 dotnet。本项目为 net10.0，请选择："
        echo "  A) 使用 --self-contained 重新运行（推荐，无需安装 .NET）"
        echo "  B) 手动安装 .NET 10 SDK: https://dotnet.microsoft.com/download/dotnet/10.0"
        exit 1
    fi
    echo "  .NET 已安装: $(dotnet --version)"
fi

# 2. 创建服务用户
echo "[2/6] 创建服务用户 $SERVICE_USER..."
if ! id "$SERVICE_USER" &>/dev/null; then
    useradd -r -s /bin/false -d "$DEPLOY_DIR" "$SERVICE_USER"
    echo "  用户已创建"
else
    echo "  用户已存在"
fi
SERVICE_GROUP=$(id -gn "$SERVICE_USER")

# 3. 创建部署目录
echo "[3/6] 创建部署目录..."
mkdir -p "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR/logs"

# 4. 发布应用（需在安装机器上有 .NET SDK，或通过已有发布包部署）
echo "[4/6] 发布应用..."
cd "$PROJECT_ROOT"
if [[ -f "AgileConfig.Server.Apisite.csproj" ]]; then
    if [[ "$SELF_CONTAINED" == "true" ]]; then
        dotnet publish AgileConfig.Server.Apisite.csproj -c Release -o /tmp/agileconfig-publish \
            -r linux-x64 --self-contained true -p:PublishSingleFile=false
        cp -r /tmp/agileconfig-publish/* "$DEPLOY_DIR/"
        rm -rf /tmp/agileconfig-publish
    else
        dotnet publish AgileConfig.Server.Apisite.csproj -c Release -o "$DEPLOY_DIR"
    fi
    echo "  发布完成"
else
    echo "  警告: 未找到项目文件，请手动将发布文件复制到 $DEPLOY_DIR"
fi

# 5. 配置 appsettings - 设置端口
echo "[5/6] 配置应用..."
if [[ -f "$DEPLOY_DIR/appsettings.json" ]]; then
    sed -i "s|\"urls\": \"http://\\*:[0-9]*\"|\"urls\": \"http://*:${PORT}\"|" "$DEPLOY_DIR/appsettings.json" || true
fi
# 确保 logs 目录存在
mkdir -p "$DEPLOY_DIR/logs"

# 6. 安装 systemd 服务
echo "[6/6] 安装 systemd 服务..."
SERVICE_FILE="/etc/systemd/system/agileconfig.service"
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=AgileConfig Server - .NET Configuration Center
Documentation=https://github.com/dotnetcore/AgileConfig
After=network.target

[Service]
Type=notify
WorkingDirectory=$DEPLOY_DIR
EOF
if [[ "$SELF_CONTAINED" == "true" ]]; then
    echo "ExecStart=$DEPLOY_DIR/AgileConfig.Server.Apisite" >> "$SERVICE_FILE"
else
    echo "ExecStart=/usr/bin/dotnet $DEPLOY_DIR/AgileConfig.Server.Apisite.dll" >> "$SERVICE_FILE"
fi
cat >> "$SERVICE_FILE" << EOF
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=agileconfig
User=$SERVICE_USER
Group=$SERVICE_GROUP
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false

[Install]
WantedBy=multi-user.target
EOF

# 设置权限
chown -R "$SERVICE_USER:$SERVICE_GROUP" "$DEPLOY_DIR"
chmod 755 "$DEPLOY_DIR"
chmod 644 "$DEPLOY_DIR"/*.dll 2>/dev/null || true
chmod +x "$DEPLOY_DIR/AgileConfig.Server.Apisite" 2>/dev/null || true

systemctl daemon-reload
systemctl enable agileconfig.service

echo ""
echo "=========================================="
echo "  安装完成！"
echo "=========================================="
echo "  启动服务: systemctl start agileconfig"
echo "  停止服务: systemctl stop agileconfig"
echo "  重启服务: systemctl restart agileconfig"
echo "  查看状态: systemctl status agileconfig"
echo "  查看日志: journalctl -u agileconfig -f"
echo ""
echo "  应用地址: http://<服务器IP>:$PORT"
echo "=========================================="
