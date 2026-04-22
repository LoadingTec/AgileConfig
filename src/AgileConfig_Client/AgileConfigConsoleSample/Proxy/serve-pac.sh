#!/usr/bin/env bash
# 在当前目录启动简易 HTTP 服务，监听 0.0.0.0，便于客户端填写 PAC URL。
# 用法: ./serve-pac.sh [端口，默认 8080]
set -euo pipefail
PORT="${1:-8080}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
echo "Serving: $ROOT"
echo "PAC example URL: http://<this-machine-ip>:${PORT}/proxy.pac"
echo "Press Ctrl+C to stop."
exec python3 -m http.server "$PORT" --bind 0.0.0.0
