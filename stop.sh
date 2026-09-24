#!/usr/bin/env bash
# RegMachine Go 停止（多平台，公共函数见 common/base.sh）
#
# 用法:
#   ./stop.sh
#   ./stop.sh --force    # 额外按 APP_PORT 强制结束监听进程
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/common/base.sh"
cd "$ROOT_DIR"

FORCE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force) FORCE=1; shift ;;
        -h|--help)
            echo "用法: ./stop.sh [--force]"
            echo "  --force, -f    除 PID 文件外，再按 APP_PORT 清理监听进程"
            exit 0
            ;;
        *)
            echo "未知参数: $1" >&2
            exit 1
            ;;
    esac
done

LoadDotEnv
InitAppPaths

STOPPED=0
old_pid="$(ReadPidFile 2>/dev/null || true)"

if [[ -n "$old_pid" ]]; then
    if PidAlive "$old_pid"; then
        echo "Stopping PID $old_pid ..."
        KillProcessTree "$old_pid"
        STOPPED=1
    else
        echo "PID 文件存在但进程已不在: $old_pid"
    fi
    ClearPidFile
fi

if [[ "$FORCE" -eq 1 || "$STOPPED" -eq 0 ]]; then
    if StopPortListeners "$APP_PORT"; then
        STOPPED=1
    fi
fi

if [[ "$STOPPED" -eq 1 ]]; then
    echo "已停止 RegMachine Go (port ${APP_PORT}, os=$(GetOSName))"
else
    echo "未发现运行中的 RegMachine Go 进程 (port ${APP_PORT})"
fi
