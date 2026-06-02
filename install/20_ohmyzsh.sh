#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

if [ -d "$HOME/.oh-my-zsh" ]; then
    log "20_ohmyzsh: 이미 설치됨(skip)"
else
    log "20_ohmyzsh: 비대화 설치"
    # RUNZSH=no: 설치 후 zsh로 진입 금지, CHSH=no: 기본 셸 변경은 setup.sh에서 처리
    RUNZSH=no CHSH=no sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended
fi
log "20_ohmyzsh: 완료"
