#!/bin/bash
# AgileConfig Server - Linux（Ubuntu 等）交互式一键安装：systemd + 主节点/从节点角色
# 用法: sudo bash install-linux-service.sh
# 非交互环境变量: ROLE=primary|secondary CLUSTER=true|false PORT=8050 DB_PROVIDER=mysql DB_CONN='...'
#                  DEPLOY_DIR=/opt/agileconfig SERVICE_USER=agileconfig SELF_CONTAINED=true|false DOTNET_PATH=/usr/bin/dotnet

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_FILE="$PROJECT_ROOT/AgileConfig.Server.Apisite.csproj"

DEPLOY_DIR="${DEPLOY_DIR:-/opt/agileconfig}"
SERVICE_USER="${SERVICE_USER:-agileconfig}"
PORT="${PORT:-8050}"
SELF_CONTAINED="${SELF_CONTAINED:-false}"
DOTNET_PATH="${DOTNET_PATH:-$(command -v dotnet 2>/dev/null || true)}"
ROLE="${ROLE:-}"
CLUSTER="${CLUSTER:-}"
DB_PROVIDER="${DB_PROVIDER:-}"
DB_CONN="${DB_CONN:-}"
ENV_DIR="/etc/agileconfig"
ENV_FILE="$ENV_DIR/agileconfig.env"
SERVICE_NAME="agileconfig"

echo "=========================================="
echo "  AgileConfig - Linux systemd 安装"
echo "=========================================="

if [[ $EUID -ne 0 ]]; then
    echo "错误: 请使用 sudo 运行"
    exit 1
fi

prompt() {
    local def="$2"
    local r
    read -r -p "$1 [${def}]: " r
    if [[ -z "${r:-}" ]]; then echo "$def"; else echo "$r"; fi
}

if [[ -z "$ROLE" ]]; then
    echo ""
    echo "选择节点角色:"
    echo "  1) 主节点 - 带管理后台 (adminConsole=true)"
    echo "  2) 从节点 - 无管理界面，加入集群 (adminConsole=false)"
    read -r -p "请输入 1 或 2 [1]: " role_choice
    role_choice="${role_choice:-1}"
    if [[ "$role_choice" == "2" ]]; then ROLE="secondary"; else ROLE="primary"; fi
fi

ROLE_LC="$(echo "$ROLE" | tr '[:upper:]' '[:lower:]')"
if [[ "$ROLE_LC" == "primary" || "$ROLE_LC" == "1" ]]; then
    ADMIN_CONSOLE="true"
    IS_PRIMARY=1
elif [[ "$ROLE_LC" == "secondary" || "$ROLE_LC" == "2" ]]; then
    ADMIN_CONSOLE="false"
    IS_PRIMARY=0
else
    echo "错误: ROLE 应为 primary 或 secondary"
    exit 1
fi

if [[ -z "$CLUSTER" ]]; then
    if [[ "$IS_PRIMARY" -eq 1 ]]; then
        c="$(prompt "主节点是否开启 cluster 自动注册 (y/n)" "y")"
        if [[ "$c" =~ ^[Nn] ]]; then CLUSTER="false"; else CLUSTER="true"; fi
    else
        c="$(prompt "从节点 cluster 自动注册? 同网段 y；跨网段 n 并在主节点手动添加节点 (y/n)" "y")"
        if [[ "$c" =~ ^[Nn] ]]; then CLUSTER="false"; else CLUSTER="true"; fi
    fi
fi
CLUSTER_LC="$(echo "$CLUSTER" | tr '[:upper:]' '[:lower:]')"
if [[ "$CLUSTER_LC" == "true" || "$CLUSTER_LC" == "1" || "$CLUSTER_LC" == "yes" ]]; then
    CLUSTER_FLAG="true"
else
    CLUSTER_FLAG="false"
fi

DEPLOY_DIR="$(prompt "部署目录" "$DEPLOY_DIR")"
PORT="$(prompt "监听端口" "$PORT")"
SERVICE_USER="$(prompt "服务运行用户" "$SERVICE_USER")"

if [[ -z "$DB_PROVIDER" ]]; then
    DB_PROVIDER="$(prompt "数据库 provider (sqlite/mysql/npgsql/sqlserver/mongodb 等)" "sqlite")"
fi
if [[ -z "$DB_CONN" ]]; then
    if [[ "$DB_PROVIDER" == "sqlite" ]]; then
        default_conn="Data Source=agile_config.db"
    else
        default_conn="Server=127.0.0.1;Database=agileconfig;User=root;Password=;Port=3306"
    fi
    echo "请输入数据库连接串 db.conn（多节点 HA 请使用共享 MySQL/PostgreSQL 等）:"
    read -r -p "[$default_conn]: " DB_CONN
    DB_CONN="${DB_CONN:-$default_conn}"
fi

if [[ "$IS_PRIMARY" -eq 1 && "$DB_PROVIDER" == "sqlite" ]]; then
    echo "提示: 多节点高可用请勿使用 SQLite。" >&2
fi

if ! id "$SERVICE_USER" &>/dev/null; then
    useradd -r -s /bin/false -d "$DEPLOY_DIR" "$SERVICE_USER"
    echo "已创建用户 $SERVICE_USER"
fi
SERVICE_GROUP="$(id -gn "$SERVICE_USER")"

mkdir -p "$DEPLOY_DIR" "$DEPLOY_DIR/logs" "$ENV_DIR"

# 发布
if [[ -f "$PROJECT_FILE" ]]; then
    echo "[发布] 目标: $DEPLOY_DIR"
    cd "$PROJECT_ROOT"
    if [[ "$SELF_CONTAINED" == "true" ]]; then
        tmp_pub="/tmp/agileconfig-publish-$$"
        dotnet publish "$PROJECT_FILE" -c Release -o "$tmp_pub" -r linux-x64 --self-contained true -p:PublishSingleFile=false
        cp -a "$tmp_pub"/. "$DEPLOY_DIR/"
        rm -rf "$tmp_pub"
    else
        if [[ -z "$DOTNET_PATH" || ! -x "$DOTNET_PATH" ]]; then
            echo "错误: 未找到 dotnet。请安装 .NET 10 或设置 SELF_CONTAINED=true / DOTNET_PATH="
            exit 1
        fi
        dotnet publish "$PROJECT_FILE" -c Release -r linux-x64 -o "$DEPLOY_DIR"
    fi
else
    echo "警告: 未找到项目文件，假设 $DEPLOY_DIR 已有发布文件"
fi

if [[ ! -f "$DEPLOY_DIR/AgileConfig.Server.Apisite.dll" ]]; then
    echo "错误: 未找到 $DEPLOY_DIR/AgileConfig.Server.Apisite.dll"
    exit 1
fi

# urls 写入 appsettings（与 install-ubuntu.sh 一致）
if [[ -f "$DEPLOY_DIR/appsettings.json" ]]; then
    sed -i "s|\"urls\": \"http://\\*:[0-9]*\"|\"urls\": \"http://*:${PORT}\"|" "$DEPLOY_DIR/appsettings.json" || true
fi

# systemd 环境文件：使用 db__* 以符合 .NET 配置约定（等价 db:provider / db:conn）
umask 077
{
    echo "ASPNETCORE_ENVIRONMENT=Production"
    echo "DOTNET_PRINT_TELEMETRY_MESSAGE=false"
    echo "urls=http://*:${PORT}"
    echo "adminConsole=${ADMIN_CONSOLE}"
    echo "cluster=${CLUSTER_FLAG}"
    echo "db__provider=${DB_PROVIDER}"
    printf 'db__conn=%s\n' "$DB_CONN"
} >"$ENV_FILE"
chmod 600 "$ENV_FILE"
chown root:root "$ENV_FILE"

UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
if [[ "$SELF_CONTAINED" == "true" ]]; then
    EXEC_START="$DEPLOY_DIR/AgileConfig.Server.Apisite"
else
    EXEC_START="${DOTNET_PATH} $DEPLOY_DIR/AgileConfig.Server.Apisite.dll"
fi

cat >"$UNIT_FILE" <<EOF
[Unit]
Description=AgileConfig Server - Configuration Center (${ROLE})
Documentation=https://github.com/dotnetcore/AgileConfig
After=network.target

[Service]
Type=notify
WorkingDirectory=$DEPLOY_DIR
EnvironmentFile=$ENV_FILE
ExecStart=$EXEC_START
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=$SERVICE_NAME
User=$SERVICE_USER
Group=$SERVICE_GROUP

[Install]
WantedBy=multi-user.target
EOF

chown -R "$SERVICE_USER:$SERVICE_GROUP" "$DEPLOY_DIR"
chmod 755 "$DEPLOY_DIR"
chmod +x "$DEPLOY_DIR/AgileConfig.Server.Apisite" 2>/dev/null || true

systemctl daemon-reload
systemctl enable "$SERVICE_NAME.service"
systemctl restart "$SERVICE_NAME.service" || systemctl start "$SERVICE_NAME.service"

echo ""
echo "=========================================="
echo "  安装完成"
echo "  角色: $ROLE  adminConsole=$ADMIN_CONSOLE  cluster=$CLUSTER_FLAG"
echo "  目录: $DEPLOY_DIR"
echo "  环境: $ENV_FILE"
echo "  地址: http://<本机IP>:${PORT}"
echo "  日志: journalctl -u $SERVICE_NAME -f"
echo "=========================================="
