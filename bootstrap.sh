#!/usr/bin/env bash
# bootstrap.sh - 一鍵啟動：檢查依賴 -> 缺就安裝 -> 編譯 proxy -> 起服務。
#
# 對應 docs/USAGE.md Step 1-4 的自動化版本。把原本要手動跑的
# 「裝 ttyd/qrencode/Go -> go build -> start.sh」串成單一入口。
#
# Usage:
#   ./bootstrap.sh -u "user:pass" [-p PROXY_PORT] [-t TTYD_PORT] [-b PROXY_BIN]
#
# 旗標與 deploy/scripts/start.sh 一致，會原樣轉發過去。
#
# 邊界：Tailscale 只檢查不自動安裝/啟動（tailscale up 會觸發互動式
# 瀏覽器 SSO，不適合腳本代跑）；缺失時提示安裝指引後中止。
set -euo pipefail

# 以腳本所在目錄為專案根，確保不論從何處呼叫路徑都正確。
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

PROXY_BIN="./server/app-tunnel-proxy"
START_SCRIPT="./deploy/scripts/start.sh"

# 從轉發旗標中攔截 -b（proxy binary 路徑），其餘原樣交給 start.sh。
parse_proxy_bin() {
  local prev=""
  for arg in "$@"; do
    if [[ "$prev" == "-b" ]]; then
      PROXY_BIN="$arg"
    fi
    prev="$arg"
  done
}
parse_proxy_bin "$@"

# -- 偵測作業系統與套件管理器 --
OS=""
INSTALL_CMD=""
case "$(uname -s)" in
  Darwin)
    OS="macos"
    if ! command -v brew >/dev/null 2>&1; then
      echo "ERROR: 需要 Homebrew 才能自動安裝依賴。" >&2
      echo "  安裝：https://brew.sh" >&2
      exit 1
    fi
    INSTALL_CMD="brew install"
    ;;
  Linux)
    OS="linux"
    if command -v apt >/dev/null 2>&1; then
      INSTALL_CMD="sudo apt install -y"
    else
      echo "ERROR: 目前自動安裝僅支援 apt（Debian/Ubuntu）。" >&2
      echo "  請依 docs/USAGE.md Step 2 手動安裝 ttyd / qrencode / Go。" >&2
      exit 1
    fi
    ;;
  *)
    echo "ERROR: 不支援的作業系統：$(uname -s)" >&2
    exit 1
    ;;
esac

echo "==> 環境：${OS}（安裝指令：${INSTALL_CMD}）"

# -- 自動安裝缺失的套件 --
ensure_installed() {
  local cmd="$1" pkg="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  [OK] $cmd 已安裝"
    return 0
  fi
  echo "  [安裝] $cmd 不存在，執行：$INSTALL_CMD $pkg"
  # shellcheck disable=SC2086
  $INSTALL_CMD $pkg
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: 安裝後仍找不到 ${cmd}，請手動檢查。" >&2
    exit 1
  fi
}

echo "==> 檢查 / 安裝外部依賴"
ensure_installed ttyd ttyd
ensure_installed qrencode qrencode

# -- Go：自動安裝並驗證版本 >= 1.21 --
ensure_go() {
  if ! command -v go >/dev/null 2>&1; then
    echo "  [安裝] go 不存在，執行：$INSTALL_CMD go"
    # shellcheck disable=SC2086
    $INSTALL_CMD go
  fi
  if ! command -v go >/dev/null 2>&1; then
    echo "ERROR: Go 安裝失敗，請手動安裝 Go 1.21+：https://go.dev/dl/" >&2
    exit 1
  fi
  # go version 輸出形如 "go version go1.22.0 darwin/arm64"
  local ver major minor
  ver="$(go version | awk '{print $3}' | sed 's/^go//')"
  major="${ver%%.*}"
  minor="$(echo "$ver" | cut -d. -f2)"
  if [[ "$major" -lt 1 || ( "$major" -eq 1 && "$minor" -lt 21 ) ]]; then
    echo "ERROR: Go 版本過舊（${ver}），需要 1.21+。請手動升級：https://go.dev/dl/" >&2
    exit 1
  fi
  echo "  [OK] go ${ver}（符合 1.21+）"
}
ensure_go

# -- Tailscale：只檢查不自動處理 --
echo "==> 檢查 Tailscale"
if ! command -v tailscale >/dev/null 2>&1; then
  echo "  [WARNING] 找不到 tailscale。手機要連線必須先安裝並加入 tailnet。" >&2
  if [[ "$OS" == "macos" ]]; then
    echo "    安裝：https://tailscale.com/download/mac" >&2
  else
    echo "    安裝：curl -fsSL https://tailscale.com/install.sh | sh" >&2
  fi
  echo "    安裝後執行 tailscale up（會跳出瀏覽器 SSO 登入）。" >&2
elif ! tailscale status >/dev/null 2>&1; then
  echo "  [WARNING] tailscale 已安裝但未連線。執行 tailscale up 加入 tailnet。" >&2
else
  echo "  [OK] tailscale 已連線"
fi

# -- 編譯 proxy（缺 binary 才編）--
echo "==> 檢查 / 編譯 Go proxy"
if [[ -x "$PROXY_BIN" ]]; then
  echo "  [OK] proxy binary 已存在：$PROXY_BIN"
else
  echo "  [編譯] go build -o app-tunnel-proxy ."
  (cd server && go build -o app-tunnel-proxy .)
  echo "  [OK] 編譯完成：$PROXY_BIN"
fi

# -- 起服務（轉發所有旗標給 start.sh）--
echo "==> 啟動服務"
exec "$START_SCRIPT" "$@"
