#!/usr/bin/env bash
# [WSL] docker를 'systemd + TCP(0.0.0.0:2375)'로 구성하고,
#       Windows 헬퍼(.ps1)를 %USERPROFILE%\.peach-win 로 복사한다.
# Windows의 docker.exe/VSCode가 같은 엔진을 쓰게 하기 위한 선택 단계.
# (setup.sh 본체에는 포함하지 않는다 — TCP 노출은 머신마다 선택)
#
# 왜 0.0.0.0인가: WSL2 NAT 모드에선 Windows localhost 포워딩이 2375를 안 넘겨주는 PC가 있어,
#   Windows는 netsh 포트프록시로 WSL eth0:2375 에 접속한다(install-windows.ps1). 포트프록시가 닿으려면
#   dockerd가 eth0에서 들어야 하므로 0.0.0.0으로 연다. NAT 모드에선 eth0가 이 PC의 Windows 호스트에서만
#   닿고 LAN엔 격리되므로 실질 host-only다. mirrored 네트워킹을 쓸 땐 반드시 127.0.0.1로 되돌릴 것
#   (mirrored에서 0.0.0.0은 진짜 LAN 노출). 자세한 내용은 README "Docker를 Windows에서 사용" 참고.
#
#   사용:  bash ~/.peach/docker-windows-tcp/setup-docker-localtcp.sh
#          (sudo 불필요 — 권한이 필요한 부분만 내부에서 sudo를 호출한다.
#           sudo로 통째 실행하면 cmd.exe interop이 막혀 Windows 복사가 실패할 수 있다)
#
# 멱등하다. WSL 초기화 후 재적용 시에도 그대로 다시 실행하면 된다.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DROPIN_DIR=/etc/systemd/system/docker.service.d

echo "[1/5] systemd drop-in 작성 (-H fd:// -H tcp://0.0.0.0:2375)  [sudo]"
sudo mkdir -p "$DROPIN_DIR"
sudo tee "$DROPIN_DIR/override.conf" >/dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375 --containerd=/run/containerd/containerd.sock
EOF

echo "[2/5] 레거시 dockerd 정리 (SysV stop + 잔여 프로세스/PID 강제 종료)  [sudo]"
sudo service docker stop 2>/dev/null || true
sudo pkill -x dockerd 2>/dev/null || true
sleep 1
sudo pkill -9 -x dockerd 2>/dev/null || true
sudo rm -f /var/run/docker.pid

echo "[3/5] systemd docker 기동  [sudo]"
sudo systemctl daemon-reload
sudo systemctl reset-failed docker 2>/dev/null || true
sudo systemctl enable --now docker
sudo systemctl restart docker
sleep 2

echo "[4/5] Windows 헬퍼를 %USERPROFILE%\\.peach-win 로 복사 (일반 사용자 권한)"
CMD_EXE="$(command -v cmd.exe 2>/dev/null || echo /mnt/c/Windows/System32/cmd.exe)"
WIN_PROFILE="$("$CMD_EXE" /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r\n')"
if [ -n "$WIN_PROFILE" ] && DEST="$(wslpath "$WIN_PROFILE" 2>/dev/null)/.peach-win" && [ -n "$DEST" ]; then
    mkdir -p "$DEST"
    cp "$HERE/install-windows.ps1" "$HERE/refresh-docker-portproxy.ps1" "$DEST/"
    echo "    복사 완료 → $DEST"
    echo "    다음(Windows **관리자** PowerShell, 모든 PC 공통 — 포트프록시에 관리자 권한 필요):"
    echo "      powershell -ExecutionPolicy Bypass -File \"\$env:USERPROFILE\\.peach-win\\install-windows.ps1\""
else
    echo "    ⚠️ Windows %USERPROFILE% 자동 감지 실패."
    echo "       docker-windows-tcp/ 의 install-windows.ps1 · refresh-docker-portproxy.ps1 을 %USERPROFILE%\\.peach-win 에 수동 복사하세요."
fi

echo "[5/5] 검증"
echo -n "    is-active : "; systemctl is-active docker 2>&1
echo -n "    listen    : "; ss -tlnp 2>/dev/null | grep 2375 || echo "(2375 리슨 없음)"
echo
echo "실패 시:  journalctl -xeu docker.service | tail -30"
