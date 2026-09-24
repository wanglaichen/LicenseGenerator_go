#!/usr/bin/env bash
# RegMachine Go 编译（参考 p08/1Build.sh）
#
# 用法:
#   ./1Build.sh
#   ./1Build.sh windows|linux|darwin|auto
#   ./1Build.sh --clean
#   ./1Build.sh -o name
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/common/base.sh"
cd "$ROOT_DIR"

CLEAN=0
OUT_NAME=""
TARGET_OS=""

Usage() {
    echo "用法: ./1Build.sh [windows|linux|darwin|auto] [--clean] [-o name]"
    echo "  windows|linux|darwin|auto  目标平台（默认 auto=本机）"
    echo "  --clean, -c                删除旧二进制后再编译"
    echo "  -o name                    输出文件名（默认 regmachine[.exe]）"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            Usage
            exit 0
            ;;
        -c|--clean)
            CLEAN=1
            shift
            ;;
        -o)
            [[ $# -ge 2 ]] || { echo "缺少 -o 参数值" >&2; exit 1; }
            OUT_NAME="$2"
            shift 2
            ;;
        windows|linux|darwin|auto)
            TARGET_OS="$1"
            shift
            ;;
        *)
            echo "未知参数: $1" >&2
            Usage >&2
            exit 1
            ;;
    esac
done

LoadDotEnv
EnsureGo

case "${TARGET_OS:-auto}" in
    windows)
        export GOOS=windows
        export GOARCH="${GOARCH:-amd64}"
        ;;
    linux)
        export GOOS=linux
        export GOARCH="${GOARCH:-amd64}"
        ;;
    darwin)
        export GOOS=darwin
        export GOARCH="${GOARCH:-amd64}"
        ;;
    auto|"")
        export GOOS="$(GetOSName)"
        if [[ "$GOOS" == "unknown" ]]; then
            echo "无法识别本机系统，请显式指定 windows|linux|darwin" >&2
            exit 1
        fi
        export GOARCH="${GOARCH:-$(go env GOARCH)}"
        ;;
esac

initFileExt
InitAppPaths

if [[ -n "$OUT_NAME" ]]; then
    BIN_NAME="$OUT_NAME"
    BIN_PATH="$ROOT_DIR/$BIN_NAME"
fi

echo "& 当前编译目标: GOOS=$GOOS GOARCH=$GOARCH 输出=$BIN_NAME"

if [[ "$CLEAN" -eq 1 ]]; then
    echo "Cleaning old binaries..."
    rm -f "$ROOT_DIR/regmachine" "$ROOT_DIR/regmachine.exe"
    [[ -f "$BIN_PATH" ]] && rm -f "$BIN_PATH"
fi

echo "go mod tidy..."
go mod tidy
IfError2Exit "go mod tidy 失败"

echo "Building $BIN_NAME ..."
go build -ldflags "-w -s" -o "$BIN_PATH" .
IfError2Exit "构建失败"

echo "OK: $BIN_PATH"
ls -lh "$BIN_PATH" 2>/dev/null || true
echo "build success done!"
