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
    # --keep-zshrc: 설치기가 ~/.zshrc 템플릿을 만들지 않게 한다. 없으면 70_link 의 인버전 entry
    #   아래에 oh-my-zsh 템플릿 본문이 남아 oh-my-zsh 가 두 번 로드되고, zshrc.shared 의
    #   alias(예: ls='eza -l')를 뒤늦게 덮어쓴다. oh-my-zsh 설정은 zshrc.shared 가 담당한다.
    RUNZSH=no CHSH=no sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended --keep-zshrc
fi
log "20_ohmyzsh: 완료"
