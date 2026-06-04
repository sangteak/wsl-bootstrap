#!/usr/bin/env bash
# 70_link: dotfile 역할 인버전 — 개인 entry 파일이 ~/.peach/*.shared 를 source/include.
# 심링크(구) 대신 멱등 블록주입. 개인 영역은 불간섭. 기존 .local은 흡수 후 .migrated 보존.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
PEACH="$HOME/.peach"

# ── zsh: instant-prompt(top) + source zshrc.shared ──
zsh_header="$(cat <<EOF
# Powerlevel10k instant prompt — 최상단 유지.
if [[ -r "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh" ]]; then
  source "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh"
fi
source "$PEACH/dotfiles/zshrc.shared"
# 아래는 개인 영역입니다 — 자유롭게 추가하세요(저장소에 올라가지 않습니다).
EOF
)"
absorb_local "$HOME/.zshrc.local" "$HOME/.zshrc"
ensure_managed_entry "$HOME/.zshrc" "$zsh_header"
log "70_link: ~/.zshrc entry 보장(인버전)"

# ── git: [include] gitconfig.shared (개인 ~/.gitconfig 소유) ──
absorb_local "$HOME/.gitconfig.local" "$HOME/.gitconfig"
git_header="$(printf '[include]\n\tpath = %s/dotfiles/gitconfig.shared' "$PEACH")"
ensure_managed_entry "$HOME/.gitconfig" "$git_header"
log "70_link: ~/.gitconfig entry 보장(인버전)"

# ── p10k: 개인 ~/.p10k.zsh 가 관리 base 를 source ──
p10k_header="source \"$PEACH/dotfiles/p10k.zsh\""
ensure_managed_entry "$HOME/.p10k.zsh" "$p10k_header"
log "70_link: ~/.p10k.zsh entry 보장(인버전)"

mkdir -p "$HOME/.local/bin"
log "70_link: 완료"
