#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

have nvim || { warn "80_nvim: nvim 미설치(50_binaries 확인) — skip"; exit 0; }

# ── ~/.config/nvim/init.vim (개인) 이 shared.vim 을 source (역할 인버전) ──
NVIM_DIR="$HOME/.config/nvim"
mkdir -p "$NVIM_DIR"
INIT="$NVIM_DIR/init.vim"
NVIM_MARK='" >>> peach:entry >>>'
if ! grep -qF "$NVIM_MARK" "$INIT" 2>/dev/null; then
    {
        printf '%s\n' "$NVIM_MARK"
        printf 'source %s/config/nvim/shared.vim\n' "$HOME/.peach"
        printf '%s\n' '" <<< peach:entry <<<'
        # 기존 개인 init.vim이 있으면 헤더 아래로 보존(없으면 건너뜀 — 그룹 종료코드 0 유지)
        if [ -f "$INIT" ]; then cat "$INIT"; fi
    } > "$INIT.tmp"
    mv "$INIT.tmp" "$INIT"
fi
log "80_nvim: ~/.config/nvim/init.vim entry 보장(인버전)"

# ── vim-plug 부트스트랩 (nvim 경로) ────────────────────
PLUG="$HOME/.local/share/nvim/site/autoload/plug.vim"
if [ -f "$PLUG" ]; then
    log "80_nvim: vim-plug 이미 설치됨"
else
    log "80_nvim: vim-plug 설치"
    curl -fsSL --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
        -o "$PLUG"
fi

# ── 플러그인 헤드리스 설치 (init.vim의 Plug 목록) ──────
# coc.nvim(do hook), nvim-treesitter(:TSUpdate, cc 필요)도 PlugInstall이 처리
log "80_nvim: PlugInstall (헤드리스)"
nvim --headless +'PlugInstall --sync' +qall 2>&1 | tail -5 || warn "80_nvim: PlugInstall 일부 실패 — nvim 수동 점검 권장"

log "80_nvim: 완료"
