# [Windows] WSL docker 로컬-TCP(2375) Windows측 설치기 — 포트프록시 + 자동 시작.
#   - (관리자) netsh 포트프록시 127.0.0.1:2375 -> WSL eth0:2375 즉시 설정
#   - (관리자) 로그온 트리거 작업 'WSL Docker Portproxy' 등록
#       (refresh-docker-portproxy.ps1: WSL 깨움 + eth0 IP 재감지 + 프록시 재설정)
#   - 사용자 환경변수 DOCKER_HOST=tcp://127.0.0.1:2375 설정
#   - Windows docker CLI(docker.exe) 유무 확인 → 없으면 winget으로 설치할지 질문
#   - 127.0.0.1:2375 연결 + docker version 으로 최종 검증
# 복사는 WSL 쪽 setup-docker-localtcp.sh 가 이 파일들을 %USERPROFILE%\.peach-win 에 넣어둔다.
#
# 실행(**관리자 PowerShell 필요** — 포트프록시가 netsh 관리자 권한을 요구):
#   powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.peach-win\install-windows.ps1"
#
# 왜 포트프록시인가: WSL2 NAT 모드에선 Windows localhost 포워딩이 2375를 안 넘겨주는 PC가 있다.
#   dockerd를 0.0.0.0:2375(NAT에선 eth0=호스트 전용, LAN 격리)로 열고 Windows는 포트프록시로 연결한다.
#   mirrored 네트워킹을 쓰면 포트프록시 없이 127.0.0.1로 직접 되지만(그땐 dockerd도 127.0.0.1로 되돌릴 것),
#   NAT 기본 환경에서 확실히 동작하는 쪽을 기본값으로 한다.  (README "Docker를 Windows에서 사용" 참고)

$ErrorActionPreference = 'Stop'

$here    = $PSScriptRoot
$refresh = Join-Path $here 'refresh-docker-portproxy.ps1'

# 관리자 확인 — netsh 포트프록시와 highest 권한 작업 등록에 필요.
$admin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Error "관리자 PowerShell에서 실행하세요 (포트프록시 설정에 관리자 권한 필요)."
    exit 1
}
if (-not (Test-Path $refresh)) {
    Write-Error "refresh-docker-portproxy.ps1 가 $here 에 없습니다. WSL에서 setup-docker-localtcp.sh 를 먼저 실행하세요(헬퍼를 여기로 복사함)."
    exit 1
}

# 레거시 wake 작업 정리 — 이제 포트프록시 작업이 WSL을 깨우므로 불필요(중복 방지).
# schtasks는 작업이 없으면 stderr로 에러를 뱉는다. ErrorActionPreference=Stop면 이게
# NativeCommandError로 승격돼 스크립트가 죽으므로, 이 구간만 Continue로 낮추고 종료코드로 판정한다.
foreach ($legacy in @("WSL Docker Autostart", "Start Docker Core")) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    schtasks /query /tn "$legacy" *>$null
    $found = ($LASTEXITCODE -eq 0)
    if ($found) { schtasks /delete /tn "$legacy" /f *>$null }
    $ErrorActionPreference = $prevEap
    if ($found) { Write-Host "      레거시 작업 제거: $legacy" }
}

# [1/5] 포트프록시 즉시 설정 (WSL 깨움 + eth0 IP 재감지 + netsh)
Write-Host "[1/5] 포트프록시 설정: 127.0.0.1:2375 -> WSL eth0:2375"
& powershell.exe -ExecutionPolicy Bypass -File $refresh
if ($LASTEXITCODE -ne 0) {
    Write-Error "포트프록시 설정 실패. 위 메시지를 확인하세요."
    exit 1
}

# [2/5] 로그온 작업 등록 — WSL IP가 부팅마다 바뀌므로 매 로그온 프록시를 재설정한다.
$tr = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$refresh`""
schtasks /create /tn "WSL Docker Portproxy" /tr $tr /sc onlogon /rl highest /f | Out-Null
Write-Host "[2/5] 작업 스케줄러 등록(onlogon, 관리자): WSL Docker Portproxy -> $refresh"

# [3/5] 접속값
[Environment]::SetEnvironmentVariable('DOCKER_HOST', 'tcp://127.0.0.1:2375', 'User')
Write-Host "[3/5] 사용자 환경변수 DOCKER_HOST=tcp://127.0.0.1:2375 설정"
Write-Host "      (localhost는 Windows에서 ::1(IPv6)로 먼저 풀리는데 dockerd는 IPv4만 리슨 -> IPv4 고정)"

# 엔진은 WSL에 있으므로 Windows엔 CLI(docker.exe)만 있으면 된다. Docker Desktop 불필요.
$docker = Get-Command docker.exe -ErrorAction SilentlyContinue
if ($docker) {
    Write-Host "[4/5] Windows docker CLI 확인: $($docker.Source)"
} else {
    Write-Host "[4/5] Windows docker CLI 없음" -ForegroundColor Yellow
    Write-Host "      (엔진은 WSL에 있으므로 Docker Desktop은 필요 없습니다. CLI만 있으면 됩니다)"
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue

    $doInstall = $false
    if (-not $winget) {
        Write-Host "      winget이 없어 자동 설치를 건너뜁니다. winget 설치 후 이 스크립트를 다시 실행하세요." -ForegroundColor Yellow
    } elseif (-not [Environment]::UserInteractive) {
        Write-Host "      비대화형 실행이라 묻지 않습니다. 수동 설치: winget install Docker.DockerCLI" -ForegroundColor Yellow
    } else {
        Write-Host "      winget으로 지금 설치할 수 있습니다 (portable 설치, 관리자 권한 불필요)."
        $answer = Read-Host "      설치할까요? [Y/n]"
        if ([string]::IsNullOrWhiteSpace($answer) -or $answer -match '^[Yy]') { $doInstall = $true }
    }

    if ($doInstall) {
        Write-Host "      winget install Docker.DockerCLI ..."
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'   # winget의 진행 출력이 종료성 에러로 승격되지 않도록
        & winget.exe install --id Docker.DockerCLI -e --source winget --accept-source-agreements --accept-package-agreements
        $wingetExit = $LASTEXITCODE
        $ErrorActionPreference = $prevEap

        if ($wingetExit -ne 0) {
            Write-Host "      winget 설치 실패 (exit $wingetExit). 네트워크/소스를 확인한 뒤 직접 실행하세요:" -ForegroundColor Yellow
            Write-Host "        winget install Docker.DockerCLI" -ForegroundColor Yellow
        } else {
            # winget portable은 %LOCALAPPDATA%\Microsoft\WinGet\Links 에 링크를 만들고 사용자 PATH를 갱신한다.
            # PATH 갱신은 새 프로세스부터라, 아래 [5/5] 검증을 위해 사용자 PATH를 현재 세션에 덧붙인다.
            # (통째 교체하면 호출자가 이 세션에서 임시로 추가해둔 항목이 사라진다)
            $env:PATH = $env:PATH + ';' + [Environment]::GetEnvironmentVariable('PATH', 'User')
            $docker = Get-Command docker.exe -ErrorAction SilentlyContinue
            if ($docker) {
                Write-Host "      설치 완료: $($docker.Source)" -ForegroundColor Green
            } else {
                Write-Host "      설치는 됐지만 docker.exe를 못 찾았습니다. '새' 터미널에서 docker --version 으로 확인하세요." -ForegroundColor Yellow
            }
        }
    } elseif ($winget) {
        Write-Host "      건너뜀. 나중에 직접 설치: winget install Docker.DockerCLI" -ForegroundColor Yellow
    }
}

Write-Host "[5/5] 연결 검증 (127.0.0.1:2375)"

# [1/5]에서 refresh가 WSL을 이미 깨웠지만, 방금 깬 경우 systemd가 dockerd를 올릴 시간이 필요하다.
function Test-DockerTcp {
    $client = $null
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $async  = $client.BeginConnect('127.0.0.1', 2375, $null, $null)
        if ($async.AsyncWaitHandle.WaitOne(1000, $false)) {   # 루프백이라 열려 있으면 1ms 미만
            $client.EndConnect($async)
            return $client.Connected
        }
        return $false
    } catch {
        return $false
    } finally {
        if ($client) { $client.Close() }
    }
}

# 최대 ~10초 재시도.
$tcpOk = $false
foreach ($attempt in 1..5) {
    $tcpOk = Test-DockerTcp
    if ($tcpOk) { break }
    Start-Sleep -Seconds 1
}

if (-not $tcpOk) {
    Write-Host "      TCP 연결 실패 -- WSL이 아직 안 떠 있거나 WSL측 설정이 미적용일 수 있습니다." -ForegroundColor Yellow
    Write-Host "        1) WSL에서: systemctl is-active docker / ss -tlnp | grep 2375  (0.0.0.0:2375 여야 함)" -ForegroundColor Yellow
    Write-Host "        2) WSL에서 setup-docker-localtcp.sh 재실행(드롭인 0.0.0.0:2375 적용)" -ForegroundColor Yellow
    Write-Host "        3) netsh interface portproxy show all  (127.0.0.1:2375 -> WSL IP 규칙 확인)" -ForegroundColor Yellow
} elseif (-not $docker) {
    Write-Host "      TCP 연결 OK (엔진 응답 확인은 docker CLI 설치 후 가능)"
} else {
    # 현재 세션에만 적용 -- User 환경변수는 새 프로세스부터라 여기서 즉시 확인하려면 필요.
    $env:DOCKER_HOST = 'tcp://127.0.0.1:2375'
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # 네이티브 stderr가 종료성 에러로 승격되지 않도록
    try {
        $srv = & docker.exe version --format '{{.Server.Version}}' 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "      TCP 연결 OK / docker 엔진 응답 OK (Server $srv)" -ForegroundColor Green
        } else {
            Write-Host "      TCP는 열렸으나 docker 응답 실패: $srv" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "      TCP는 열렸으나 docker 호출 예외: $($_.Exception.Message)" -ForegroundColor Yellow
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

Write-Host ""
Write-Host "완료. '새' 터미널을 열고(환경변수는 새 프로세스부터 적용) 확인:  docker ps"
Write-Host "메모:"
Write-Host "  - WSL IP는 부팅마다 바뀌지만, 로그온 작업 'WSL Docker Portproxy'가 매번 프록시를 재설정합니다."
Write-Host "  - 포트프록시 없이 쓰려면 %USERPROFILE%\.wslconfig 에 [wsl2] / networkingMode=mirrored 후"
Write-Host "    WSL 드롭인을 127.0.0.1:2375 로 되돌리세요 (mirrored에서 0.0.0.0은 LAN 노출)."
