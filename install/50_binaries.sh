#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

ARCH=amd64
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ── go (최신, /usr/local/go) ───────────────────────────
if have go; then
    log "go: 이미 설치됨($(go version | awk '{print $3}')) — skip"
else
    GO_VER="$(curl -fsSL https://go.dev/VERSION?m=text | head -1)"
    log "go: 설치 $GO_VER"
    curl -fsSL "https://go.dev/dl/${GO_VER}.linux-${ARCH}.tar.gz" -o "$TMP/go.tgz"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "$TMP/go.tgz"
fi

# ── kubectl (최신 stable, /usr/local/bin) ──────────────
if have kubectl; then
    log "kubectl: 이미 설치됨 — skip"
else
    KVER="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
    log "kubectl: 설치 $KVER"
    curl -fsSL "https://dl.k8s.io/release/${KVER}/bin/linux/${ARCH}/kubectl" -o "$TMP/kubectl"
    sudo install -m 0755 "$TMP/kubectl" /usr/local/bin/kubectl
fi

# ── helm (공식 스크립트) ───────────────────────────────
if have helm; then
    log "helm: 이미 설치됨 — skip"
else
    log "helm: 설치"
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# ── neovim (최신 release tarball, /opt + 심링크) ───────
if have nvim; then
    log "nvim: 이미 설치됨($(nvim --version | head -1)) — skip"
else
    log "nvim: 설치(latest release)"
    curl -fsSL https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz -o "$TMP/nvim.tgz"
    sudo rm -rf /opt/nvim
    sudo mkdir -p /opt/nvim
    sudo tar -C /opt/nvim --strip-components=1 -xzf "$TMP/nvim.tgz"
    sudo ln -sfn /opt/nvim/bin/nvim /usr/local/bin/nvim
fi

log "50_binaries: 완료"
