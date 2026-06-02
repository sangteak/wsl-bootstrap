# [Windows] WSL docker 로컬-TCP 자동 시작 등록기.
#   - 로그온 트리거 작업 스케줄러 등록(같은 폴더의 start-wsl-docker.vbs → WSL을 깨워 docker/TCP 준비)
#   - 사용자 환경변수 DOCKER_HOST=tcp://localhost:2375 설정
# 복사는 WSL 쪽 setup-docker-localtcp.sh 가 이미 이 파일들을 %USERPROFILE%\.peach-win 에 넣어둔다.
#
# 실행(관리자 불필요, 모든 PC 공통):
#   powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.peach-win\install-windows.ps1"

$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
$vbs  = Join-Path $here 'start-wsl-docker.vbs'

if (-not (Test-Path $vbs)) {
    Write-Error "start-wsl-docker.vbs 가 $here 에 없습니다. WSL에서 setup-docker-localtcp.sh 를 먼저 실행하세요(헬퍼를 여기로 복사함)."
    exit 1
}

schtasks /create /tn "WSL Docker Autostart" /tr "wscript.exe `"$vbs`"" /sc onlogon /f | Out-Null
Write-Host "[1/2] 작업 스케줄러 등록(onlogon): WSL Docker Autostart -> $vbs"

[Environment]::SetEnvironmentVariable('DOCKER_HOST', 'tcp://localhost:2375', 'User')
Write-Host "[2/2] 사용자 환경변수 DOCKER_HOST=tcp://localhost:2375 설정"

Write-Host ""
Write-Host "완료. '새' 터미널을 열고(환경변수는 새 프로세스부터 적용) 확인:  docker ps"
Write-Host "메모:"
Write-Host "  - localhost가 WSL에 안 닿으면 %USERPROFILE%\.wslconfig 에 [wsl2] / networkingMode=mirrored 추가."
Write-Host "  - 옛 dockerd 시작 작업(예: start-dockerd-in-wsl.bat)이 있으면 비활성화/삭제하세요."
