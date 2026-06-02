#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

log "10_apt: 기본 패키지 설치"
ensure_apt \
    zsh \
    git curl wget unzip \
    eza bat fd-find jq \
    build-essential \
    nodejs npm \
    universal-ctags

# Ubuntu에서 bat 바이너리는 batcat 이름으로 설치됨 → .zshrc alias(cat=batcat)와 일치
# nodejs/npm: nvim coc.nvim 의존, universal-ctags: nvim tagbar 의존, build-essential: treesitter :TSUpdate 의존
log "10_apt: 완료"
