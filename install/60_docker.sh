#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

# Docker Engine(docker-ce)을 WSL 내부에 네이티브 설치한다.
# WSL의 systemd(90_wsl_conf가 활성화)가 데몬을 관리하므로, 과거의
# 'dockerd over TCP 2375 + Windows 배치 + Task Scheduler' 우회는 불필요하다.
# 데몬은 기본 유닉스 소켓(/var/run/docker.sock, 로컬 전용)을 사용한다.

WSL_USER="${SUDO_USER:-$USER}"

# ── 엔진 설치 (apt 공식 저장소) ────────────────────────
if have docker; then
    log "docker: 이미 설치됨($(docker --version 2>/dev/null | awk '{print $3}' | tr -d ,)) — 엔진 설치 skip"
else
    log "docker: 공식 apt 저장소 등록 + docker-ce 설치"
    ensure_apt ca-certificates curl

    # GPG 키 (없을 때만 받음)
    sudo install -m 0755 -d /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/docker.asc ]; then
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
    fi

    # apt 소스 등록 (멱등 덮어쓰기)
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    ensure_apt docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# ── docker 그룹 (sudo 없이 docker 실행 + minikube docker 드라이버) ──
if id -nG "$WSL_USER" 2>/dev/null | grep -qw docker; then
    log "docker: $WSL_USER 가 이미 docker 그룹 — skip"
else
    log "docker: $WSL_USER 를 docker 그룹에 추가"
    sudo usermod -aG docker "$WSL_USER"
    warn "docker 그룹 적용은 새 로그인 세션부터 — 현재 셸은 'newgrp docker' 또는 재로그인 필요"
fi

# ── 데몬 자동 시작 (systemd) ───────────────────────────
# 클린 머신 최초 실행 시 90_wsl_conf가 wsl.conf만 쓰고 systemd는 아직 미활성일 수 있다.
# 그 경우 'wsl --shutdown' 후 재진입 → setup.sh 재실행하면 이 블록이 데몬을 등록한다.
if [ -d /run/systemd/system ]; then
    sudo systemctl enable --now docker
    log "docker: systemd 등록 완료(WSL 부팅 시 자동 시작)"
else
    warn "docker: systemd 미활성 — 데몬 자동 시작 미설정"
    warn "  PowerShell에서 'wsl --shutdown' 후 WSL 재진입 → setup.sh 재실행하면 적용됩니다"
fi

log "60_docker: 완료"
