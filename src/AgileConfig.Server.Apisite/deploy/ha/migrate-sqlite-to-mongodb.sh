#!/usr/bin/env bash
# 一键调用仓库内迁移工具：SQLite -> MongoDB
# 用法:
#   bash migrate-sqlite-to-mongodb.sh --sqlite 'Data Source=/opt/agileconfig/agile_config.db' --mongo 'mongodb://127.0.0.1:27017/AgileConfig'
#   bash migrate-sqlite-to-mongodb.sh --sqlite '...' --mongo '...' --dry-run
#   bash migrate-sqlite-to-mongodb.sh --sqlite '...' --mongo '...' --drop

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PROJ="$REPO_ROOT/src/AgileConfig.Tools.MigrateSqliteToMongo/AgileConfig.Tools.MigrateSqliteToMongo.csproj"

if [[ ! -f "$PROJ" ]]; then
  echo "未找到迁移项目: $PROJ" >&2
  exit 1
fi

SQLITE=""
MONGO=""
DRY_RUN=false
DROP=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --sqlite) SQLITE="$2"; shift 2 ;;
    --mongo) MONGO="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --drop) DROP=true; shift ;;
    -h|--help)
      echo "用法: $0 --sqlite 'Data Source=...' --mongo 'mongodb://...' [--dry-run] [--drop]"
      exit 0
      ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$SQLITE" ]]; then
  read -r -p "SQLite 连接串: " SQLITE
fi
if [[ -z "$MONGO" ]]; then
  read -r -p "MongoDB URI: " MONGO
fi

ARGS=(run -c Release --project "$PROJ" -- --sqlite "$SQLITE" --mongo "$MONGO")
if [[ "$DRY_RUN" == true ]]; then ARGS+=(--dry-run); fi
if [[ "$DROP" == true ]]; then ARGS+=(--drop --yes); fi

echo "dotnet ${ARGS[*]}"
exec dotnet "${ARGS[@]}"
