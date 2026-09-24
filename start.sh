#!/usr/bin/env bash
# RegMachine Go 启动
#
# 用法:
#   ./start.sh              # 后台启动
#   ./start.sh --fg         # 前台启动
#   ./start.sh --kill       # 端口占用时先结束旧进程
#   ./start.sh --rebuild    # 强制重新编译
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/common/base.sh"
cd "$ROOT_DIR"

KILL_PORT=0
FOREGROUND=0
REBUILD=0

Usage() {
    echo "用法: ./start.sh [--kill] [--fg] [--rebuild]"
    echo "  --kill, -k          APP_PORT 被占用时自动结束旧进程"
    echo "  --fg, --foreground  前台运行（默认后台）"
    echo "  --rebuild, -r       强制重新编译二进制"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -k|--kill) KILL_PORT=1; shift ;;
        -f|--fg|--foreground) FOREGROUND=1; shift ;;
        -r|--rebuild) REBUILD=1; shift ;;
        -h|--help) Usage; exit 0 ;;
        *)
            echo "未知参数: $1" >&2
            Usage >&2
            exit 1
            ;;
    esac
done

LoadDotEnv
InitAppPaths

AlreadyRunning() {
    local old_pid
    old_pid="$(ReadPidFile 2>/dev/null || true)"
    if [[ -n "$old_pid" ]] && PidAlive "$old_pid"; then
        echo "服务已在运行 (PID $old_pid)。先执行 ./stop.sh 或使用 --kill。" >&2
        return 0
    fi
    ClearPidFile
    return 1
}

# 已打包二进制存在则直接启动，不要求本机安装 Go
BinaryReady() {
    # Windows 下可执行文件未必带 +x，存在即可
    [[ -f "$BIN_PATH" ]]
}

if [[ "$KILL_PORT" -eq 1 ]]; then
    StopPortListeners "$APP_PORT" || true
    ClearPidFile
elif AlreadyRunning; then
    exit 1
fi

if [[ "$REBUILD" -eq 1 ]] || ! BinaryReady; then
    EnsureGo
    echo "Building via 1Build.sh ..."
    if [[ "$REBUILD" -eq 1 ]]; then
        "$ROOT_DIR/1Build.sh" --clean
    else
        "$ROOT_DIR/1Build.sh"
    fi
fi

if ! BinaryReady; then
    echo "二进制不存在: $BIN_PATH" >&2
    echo "请先在有 Go 的机器执行 ./1Build.sh，再把 ${BIN_NAME} 一并拷贝过来；或本机安装 Go 后重试。" >&2
    exit 1
fi

echo "Starting RegMachine Go [$(GetOSName)]: http://127.0.0.1:${APP_PORT}"

if [[ "$FOREGROUND" -eq 1 ]]; then
    exec "$BIN_PATH"
fi

nohup "$BIN_PATH" >>"$LOG_FILE" 2>&1 &
WritePidFile $!
echo "PID $(ReadPidFile)  日志: $LOG_FILE"
echo "停止: ./stop.sh"
