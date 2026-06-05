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
    build-essential make \
    universal-ctags \
    wslu

# Ubuntu에서 bat 바이너리는 batcat 이름으로 설치됨 → .zshrc alias(cat=batcat)와 일치
# universal-ctags: nvim tagbar 의존, build-essential: treesitter :TSUpdate 의존
# make: 이 저장소의 핵심 도구 mk(Makefile)의 직접 의존성 — build-essential에 포함되나 명시
# wslu: wslview 제공 → WSL에서 'aws login' 등이 Windows 기본 브라우저를 자동으로 열게(BROWSER=wslview)

# ── nodejs/npm (nvim coc.nvim 의존) ────────────────────
# '명령 존재'로 판정한다. NodeSource/nvm 등으로 이미 node/npm이 있으면 재사용.
# (우분투 npm 패키지는 node-* 마이크로패키지에 의존하므로 NodeSource nodejs와 공존 불가.
#  ensure_apt 의 dpkg 기준으로는 매번 우분투 npm 설치를 시도해 'held broken packages' 충돌이 난다.)
if have node && have npm; then
    log "node/npm: 이미 설치됨(node $(node --version), npm $(npm --version)) — skip"
else
    ensure_apt nodejs npm
fi
log "10_apt: 완료"
