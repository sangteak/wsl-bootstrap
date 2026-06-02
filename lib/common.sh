#!/usr/bin/env bash
# 공통 멱등 헬퍼. 각 모듈 상단에서 source 한다.
# 이 파일은 단독 실행되지 않는다.

set -euo pipefail

# ── 로깅 ──────────────────────────────────────────────
log()  { printf '\033[1;32m[peach]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[peach:warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[peach:err]\033[0m %s\n' "$*" >&2; exit 1; }

# ── 명령 존재 확인 ─────────────────────────────────────
# have <cmd> : 명령이 PATH에 있으면 0, 없으면 1
have() { command -v "$1" >/dev/null 2>&1; }

# ── apt 멱등 설치 ──────────────────────────────────────
# ensure_apt <pkg...> : dpkg에 없는 패키지만 골라 설치
ensure_apt() {
    local missing=()
    local pkg
    for pkg in "$@"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        log "apt: 모두 설치됨 ($*)"
        return 0
    fi
    log "apt: 설치 ${missing[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y "${missing[@]}"
}

# ── git clone-or-pull 멱등 ─────────────────────────────
# clone_or_pull <repo-url> <dest-dir>
clone_or_pull() {
    local url="$1" dest="$2"
    if [ -d "$dest/.git" ]; then
        log "git pull: $dest"
        git -C "$dest" pull --ff-only --quiet || warn "pull 실패(로컬 변경?): $dest"
    elif [ -e "$dest" ]; then
        warn "이미 존재하나 git 저장소가 아님(건너뜀): $dest"
    else
        log "git clone: $url → $dest"
        git clone --depth 1 --quiet "$url" "$dest"
    fi
}

# ── 심링크 + 기존 파일 백업 ────────────────────────────
# link_with_backup <src> <dst> [backup-dir]
# - dst가 이미 src를 가리키는 심링크면 no-op
# - dst가 실제 파일/다른 심링크면 backup-dir로 옮기고 심링크 생성
link_with_backup() {
    local src="$1" dst="$2" backup="${3:-$HOME/.peach-backup}"
    [ -e "$src" ] || die "link 원본 없음: $src"
    # 이미 올바른 심링크면 skip
    if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
        return 0
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mkdir -p "$backup"
        local stamp; stamp="$(date +%Y%m%d%H%M%S%N)"
        mv "$dst" "$backup/$(basename "$dst").$stamp"
        warn "기존 파일 백업: $dst → $backup/$(basename "$dst").$stamp"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
    log "link: $dst → $src"
}
