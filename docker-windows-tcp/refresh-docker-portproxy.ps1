# [Windows] WSL2 eth0:2375 -> Windows 127.0.0.1:2375 netsh 포트프록시 갱신.
#   WSL의 eth0 IP는 NAT 모드에서 부팅마다 바뀌므로, 로그온 시 재감지해 프록시를 다시 건다.
#   install-windows.ps1 이 이 스크립트를 'WSL Docker Portproxy'(onlogon, 관리자) 작업으로 등록한다.
#   관리자 권한 필요 (netsh portproxy).

$ErrorActionPreference = 'Stop'

# netsh portproxy는 관리자 권한이 없으면 조용히 실패한다 -- 명확히 걸러낸다.
$admin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Error "관리자 PowerShell에서 실행하세요 (netsh 포트프록시에 관리자 권한 필요)."
    exit 1
}

# WSL을 깨우고 eth0 IP를 읽는다. (wsl.exe 호출이 꺼져 있던 WSL을 부팅시킨다)
$ip = (wsl.exe -e sh -c "ip -4 addr show eth0 | grep -oP 'inet \K[0-9.]+'").Trim()
if (-not $ip) {
    Write-Error "WSL eth0 IP를 찾지 못했습니다. WSL이 떠 있는지 확인하세요."
    exit 1
}

# 현재 WSL IP로 프록시를 다시 건다. (listenaddress=127.0.0.1: 로컬 호스트만 수신)
netsh interface portproxy delete v4tov4 listenport=2375 listenaddress=127.0.0.1 2>$null | Out-Null
netsh interface portproxy add v4tov4 listenport=2375 listenaddress=127.0.0.1 connectport=2375 connectaddress=$ip
if ($LASTEXITCODE -ne 0) {
    Write-Error "netsh 포트프록시 추가 실패 (exit $LASTEXITCODE)."
    exit 1
}

Write-Host "portproxy set: 127.0.0.1:2375 -> ${ip}:2375"
netsh interface portproxy show all
