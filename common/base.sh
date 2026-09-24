#!/usr/bin/env bash
# 公共脚本函数（参考 p08/base.sh），供 1Build.sh / start.sh / stop.sh 复用。
# 支持: Windows (Git Bash/MSYS/Cygwin)、Linux、macOS。

# 执行命令失败则提示并退出
IfError2Exit() {
    if [[ $? -ne 0 ]]; then
        local tip="${1:-执行返回错误，任意键退出...}"
        read -n 1 -r -p "$tip" || true
        echo
        exit 1
    fi
}

# GetOSName 返回: linux | windows | darwin | unknown
# 传参 GOOS 时优先使用环境变量 GOOS（便于交叉编译探测）
GetOSName() {
    if [[ "${1:-}" == "GOOS" && -n "${GOOS:-}" ]]; then
        echo "$GOOS"
        return 0
    fi

    local uname_s uname_o
    uname_s="$(uname -s 2>/dev/null || true)"
    uname_o="$(uname -o 2>/dev/null || true)"

    case "${OSTYPE:-}" in
        linux-gnu*|linux*)
            echo "linux"; return 0
            ;;
        darwin*)
            echo "darwin"; return 0
            ;;
        msys*|cygwin*|win32*|mingw*)
            echo "windows"; return 0
            ;;
    esac

    case "$uname_s" in
        Linux*)  echo "linux"; return 0 ;;
        Darwin*) echo "darwin"; return 0 ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows"; return 0 ;;
    esac

    case "$uname_o" in
        GNU/Linux) echo "linux"; return 0 ;;
        Msys|Cygwin) echo "windows"; return 0 ;;
    esac

    if [[ "${OS:-}" == "Windows_NT" ]]; then
        echo "windows"
        return 0
    fi

    echo "unknown"
    return 1
}

IsWindows() { [[ "$(GetOSName)" == "windows" ]]; }
IsLinux()   { [[ "$(GetOSName)" == "linux" ]]; }
IsDarwin()  { [[ "$(GetOSName)" == "darwin" ]]; }

# windows 下 msys 调用原生程序时，路径常需转成 Windows 格式
CYG_WinPath() {
    if IsWindows && command -v cygpath.exe >/dev/null 2>&1; then
        cygpath.exe -w "$*"
    else
        echo "$*"
    fi
}

CYG_UnixPath() {
    if IsWindows && command -v cygpath.exe >/dev/null 2>&1; then
        cygpath.exe -a -u "$*"
    else
        echo "$*"
    fi
}

pause() {
    if [[ "${1:-}" == "-t" && -n "${2:-}" ]]; then
        read -n 1 -t "$2" -r -p "press any key or wait ${2}s to continue..." || true
    else
        read -n 1 -t 30 -r -p "press any key to continue..." || true
    fi
    echo
    true
}

# 根据 GOOS / 本机系统设置可执行文件后缀 SysExt / fileExt
initFileExt() {
    fileExt=".exe"
    if [[ "${GOOS:-}" == "linux" || "${GOOS:-}" == "darwin" ]]; then
        fileExt=""
    fi
    if [[ -z "${GOOS:-}" ]]; then
        case "$(GetOSName)" in
            windows) fileExt=".exe" ;;
            linux|darwin) fileExt="" ;;
            *) fileExt=".exe" ;;
        esac
    fi
    SysExt="$fileExt"
}

# 加载项目根目录 .env（不覆盖已有环境变量）
LoadDotEnv() {
    local env_file="${1:-$ROOT_DIR/.env}"
    [[ -f "$env_file" ]] || return 0
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
}

EnsureGo() {
    if ! command -v go >/dev/null 2>&1; then
        echo "未找到 go 命令，请先安装 Go。" >&2
        exit 1
    fi
}

# 应用名与路径约定
InitAppPaths() {
    initFileExt
    APP_NAME="${APP_NAME:-regmachine}"
    BIN_NAME="${APP_NAME}${fileExt}"
    BIN_PATH="${ROOT_DIR}/${BIN_NAME}"
    RUN_DIR="${ROOT_DIR}/.run"
    PID_FILE="${RUN_DIR}/${APP_NAME}.pid"
    LOG_FILE="${RUN_DIR}/${APP_NAME}.log"
    APP_HOST="${APP_HOST:-0.0.0.0}"
    APP_PORT="${APP_PORT:-9212}"
    mkdir -p "$RUN_DIR"
}

PortInUse() {
    local port="${1:-}"
    [[ -z "$port" ]] && return 1
    if command -v lsof >/dev/null 2>&1; then
        lsof -ti tcp:"$port" >/dev/null 2>&1
    elif command -v ss >/dev/null 2>&1; then
        ss -ltn 2>/dev/null | grep -qE "[:.]${port}[[:space:]]"
    elif command -v netstat >/dev/null 2>&1; then
        netstat -ano 2>/dev/null | grep -qE ":${port}[[:space:]]+.*(LISTEN|LISTENING)"
    else
        return 1
    fi
}

CollectPortPids() {
    local port="${1:-}"
    if command -v lsof >/dev/null 2>&1; then
        lsof -ti tcp:"$port" 2>/dev/null || true
    elif command -v netstat >/dev/null 2>&1; then
        netstat -ano 2>/dev/null | awk -v target=":${port}" '
            $0 ~ target && ($0 ~ /LISTENING/ || $0 ~ /LISTEN/) { print $NF }
        ' || true
    fi
}

KillProcessTree() {
    local pid="${1:-}"
    [[ -z "$pid" || "$pid" == "0" ]] && return 0
    if IsWindows; then
        if command -v taskkill.exe >/dev/null 2>&1; then
            taskkill.exe //PID "$pid" //F //T >/dev/null 2>&1 || true
        elif command -v powershell.exe >/dev/null 2>&1; then
            powershell.exe -NoProfile -Command "Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue" >/dev/null 2>&1 || true
        else
            kill -KILL "$pid" >/dev/null 2>&1 || true
        fi
    else
        kill -TERM "$pid" >/dev/null 2>&1 || true
        sleep 1
        if kill -0 "$pid" >/dev/null 2>&1; then
            kill -KILL "$pid" >/dev/null 2>&1 || true
        fi
    fi
}

PidAlive() {
    local pid="${1:-}"
    [[ -z "$pid" ]] && return 1
    if IsWindows; then
        if command -v powershell.exe >/dev/null 2>&1; then
            powershell.exe -NoProfile -Command "Get-Process -Id $pid -ErrorAction SilentlyContinue" >/dev/null 2>&1
        else
            kill -0 "$pid" >/dev/null 2>&1
        fi
    else
        kill -0 "$pid" >/dev/null 2>&1
    fi
}

StopPortListeners() {
    local port="${1:-$APP_PORT}"
    local pid
    local seen=" "

    if ! PortInUse "$port"; then
        return 0
    fi

    local found=0
    while read -r pid; do
        [[ -z "$pid" || "$pid" == "0" ]] && continue
        case "$seen" in
            *" $pid "*) continue ;;
        esac
        seen="${seen}${pid} "
        if [[ $found -eq 0 ]]; then
            echo -n "Stopping process(es) on port ${port}:"
            found=1
        fi
        echo -n " $pid"
        KillProcessTree "$pid"
    done < <(CollectPortPids "$port")

    if [[ $found -eq 0 ]]; then
        echo "Port ${port} is in use, but PID could not be resolved." >&2
        return 1
    fi
    echo
}

WritePidFile() {
    local pid="${1:-}"
    [[ -n "$pid" ]] || return 1
    mkdir -p "$RUN_DIR"
    echo "$pid" >"$PID_FILE"
}

ReadPidFile() {
    [[ -f "$PID_FILE" ]] || return 1
    tr -d '[:space:]' <"$PID_FILE"
}

ClearPidFile() {
    rm -f "$PID_FILE"
}

# 解析脚本所在项目根目录（调用方应先设 ROOT_DIR，或由此初始化）
ResolveRootDir() {
    local caller="${1:-${BASH_SOURCE[1]:-$0}}"
    ROOT_DIR="$(cd "$(dirname "$caller")" && pwd)"
    # 若脚本在子目录，可向上找 go.mod
    if [[ ! -f "$ROOT_DIR/go.mod" && -f "$ROOT_DIR/../go.mod" ]]; then
        ROOT_DIR="$(cd "$ROOT_DIR/.." && pwd)"
    fi
    cd "$ROOT_DIR"
}
