#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

# 현재 환경과 동일하게 ~/powerlevel10k 에 clone (.zshrc가 이 경로를 source)
clone_or_pull https://github.com/romkatv/powerlevel10k.git "$HOME/powerlevel10k"
log "30_p10k: 완료"
