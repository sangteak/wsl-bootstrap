#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

# ── dotfiles → ~/.<name> ───────────────────────────────
# dotfiles/zshrc → ~/.zshrc, p10k.zsh → ~/.p10k.zsh, gitconfig → ~/.gitconfig
# *.example 는 링크하지 않음(템플릿)
for f in "$REPO_DIR"/dotfiles/*; do
    base="$(basename "$f")"
    case "$base" in
        *.example) continue ;;
    esac
    link_with_backup "$f" "$HOME/.$base"
done

# ── config/<sub>/<file> → ~/.config/<sub>/<file> (중첩) ─
# config/nvim/init.vim → ~/.config/nvim/init.vim
if [ -d "$REPO_DIR/config" ]; then
    while IFS= read -r -d '' f; do
        rel="${f#"$REPO_DIR"/config/}"
        link_with_backup "$f" "$HOME/.config/$rel"
    done < <(find "$REPO_DIR/config" -type f -print0)
fi

# ── scripts/*.sh → ~/.local/bin/<name> (.sh 제거) ──────
mkdir -p "$HOME/.local/bin"
shopt -s nullglob
for f in "$REPO_DIR"/scripts/*.sh; do
    chmod +x "$f"
    name="$(basename "$f" .sh)"
    link_with_backup "$f" "$HOME/.local/bin/$name"
done
shopt -u nullglob

log "70_link: 완료"
