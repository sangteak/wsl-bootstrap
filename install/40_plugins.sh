#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# oh-my-zsh 외부 플러그인 (.zshrc plugins=(...) 목록과 일치)
clone_or_pull https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_or_pull https://github.com/zsh-users/zsh-autosuggestions.git \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

# fzf (~/.fzf 에 clone 후 비대화 설치)
clone_or_pull https://github.com/junegunn/fzf.git "$HOME/.fzf"
"$HOME/.fzf/install" --key-bindings --completion --no-update-rc

log "40_plugins: 완료"
