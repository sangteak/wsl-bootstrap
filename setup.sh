#!/usr/bin/env bash
set -euo pipefail

PEACH_DIR="$HOME/.peach"
REPO_URL="https://github.com/sangteak/wsl-bootstrap.git"

# ── 1. git/curl 확보 (부트스트랩) ─────────────────────
if ! command -v git >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    echo "[peach] git/curl 설치"
    sudo apt-get update -qq
    sudo apt-get install -y git curl
fi

# ── 2. self-clone: ~/.peach 에서 실행 중이 아니면 clone/pull 후 재실행 ──
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$THIS_DIR" != "$PEACH_DIR" ]; then
    if [ -d "$PEACH_DIR/.git" ]; then
        echo "[peach] git pull: $PEACH_DIR"
        git -C "$PEACH_DIR" pull --ff-only --quiet || true
    else
        echo "[peach] git clone → $PEACH_DIR (ext4)"
        git clone --quiet "$REPO_URL" "$PEACH_DIR"
    fi
    exec bash "$PEACH_DIR/setup.sh" "$@"
fi

# 여기부터는 ~/.peach 안에서 실행됨
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib/common.sh
source "$PEACH_DIR/lib/common.sh"

# ── 3. install 모듈 순차 실행 (멱등) ───────────────────
for mod in "$PEACH_DIR"/install/[0-9]*.sh; do
    log "── 실행: $(basename "$mod") ──"
    bash "$mod" || die "모듈 실패: $(basename "$mod") — 원인 확인 후 setup.sh 재실행(멱등)"
done

# ── 4. 기본 셸 zsh 전환 (chsh → 실패 시 bashrc 폴백) ──
ZSH_BIN="$(command -v zsh)"
if [ "${SHELL:-}" != "$ZSH_BIN" ]; then
    if chsh -s "$ZSH_BIN" 2>/dev/null; then
        log "기본 셸을 zsh로 변경(다음 로그인부터 적용)"
    else
        if ! grep -q 'exec zsh' "$HOME/.bashrc" 2>/dev/null; then
            printf '\n# peach: 로그인 시 zsh 진입\n[ -t 1 ] && exec zsh\n' >> "$HOME/.bashrc"
            warn "chsh 실패 → ~/.bashrc에 'exec zsh' 폴백 추가"
        fi
    fi
fi

# ── 5. 검증 ────────────────────────────────────────────
log "── 검증 ──"
# 검증은 setup의 bash 프로세스에서 실행되므로, zshrc에만 있는 PATH(go/fzf 등)를 보강한다.
# (이 export는 검증 한정 — 실제 PATH는 .zshrc가 셸 시작 시 설정)
export PATH="/usr/local/go/bin:$HOME/.fzf/bin:$HOME/.local/bin:$PATH"
fail=0
# 대화형 zsh가 .zshrc를 끝까지 로드하고 명령을 실행하는지 '양성 마커'로 검증.
# (zsh -ic 'exit' 종료코드는 비-TTY 환경에서 p10k gitstatus 초기화 실패에 오염되어 거짓 음성을 냄)
if zsh -ic 'print -rn -- PEACH_OK' 2>/dev/null | grep -q PEACH_OK; then log "✅ zsh 대화형 로드 OK"; else warn "❌ zsh 로드 실패"; fail=1; fi
for t in zsh git eza batcat nvim kubectl helm go fzf aws minikube make docker eksctl; do
    if command -v "$t" >/dev/null 2>&1; then log "✅ $t"; else warn "❌ $t 없음"; fail=1; fi
done
if [ -f "$HOME/powerlevel10k/powerlevel10k.zsh-theme" ]; then log "✅ p10k 테마 존재"; else warn "❌ p10k 없음"; fail=1; fi
if [ -f "$HOME/.config/nvim/init.vim" ]; then log "✅ nvim init.vim 배치됨"; else warn "❌ nvim init.vim 없음"; fail=1; fi
if [ -d "$HOME/.vim/plugged" ]; then log "✅ nvim 플러그인 설치됨"; else warn "⚠️ nvim 플러그인 미설치(80_nvim 확인)"; fi

if [ "$fail" -eq 0 ]; then
    log "🎉 setup 완료. 새 셸을 열면 환경이 적용됩니다."
else
    warn "일부 항목 실패 — 위 ❌ 확인 후 setup.sh 재실행(멱등)"
fi
[ -f /etc/wsl.conf ] && warn "wsl.conf가 변경되었다면 Windows에서 'wsl --shutdown' 1회 필요"
