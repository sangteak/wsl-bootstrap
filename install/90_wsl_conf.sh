#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

WSL_USER="${SUDO_USER:-$USER}"
DESIRED="$(cat <<EOF
[boot]
systemd=true

[user]
default=$WSL_USER
EOF
)"

if [ -f /etc/wsl.conf ] && [ "$(cat /etc/wsl.conf)" = "$DESIRED" ]; then
    log "90_wsl_conf: 이미 동일(skip)"
else
    log "90_wsl_conf: /etc/wsl.conf 작성(sudo)"
    printf '%s\n' "$DESIRED" | sudo tee /etc/wsl.conf >/dev/null
    warn "wsl.conf 변경됨 → Windows PowerShell에서 'wsl --shutdown' 1회 후 재진입 필요"
fi
log "90_wsl_conf: 완료"
