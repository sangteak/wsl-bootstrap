# [Windows] WSL docker 로컬-TCP 자동 시작 등록기.
#   - 로그온 트리거 작업 스케줄러 등록(같은 폴더의 start-wsl-docker.vbs → WSL을 깨워 docker/TCP 준비)
#   - 사용자 환경변수 DOCKER_HOST=tcp://127.0.0.1:2375 설정
#   - Windows docker CLI(docker.exe) 유무 확인 → 없으면 winget으로 설치할지 질문
#   - 127.0.0.1:2375 연결 + docker version 으로 최종 검증
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
Write-Host "[1/4] 작업 스케줄러 등록(onlogon): WSL Docker Autostart -> $vbs"

[Environment]::SetEnvironmentVariable('DOCKER_HOST', 'tcp://127.0.0.1:2375', 'User')
Write-Host "[2/4] 사용자 환경변수 DOCKER_HOST=tcp://127.0.0.1:2375 설정"
Write-Host "      (localhost는 Windows에서 ::1(IPv6)로 먼저 풀리는데 dockerd는 IPv4만 리슨 -> IPv4 고정)"

# 엔진은 WSL에 있으므로 Windows엔 CLI(docker.exe)만 있으면 된다. Docker Desktop 불필요.
$docker = Get-Command docker.exe -ErrorAction SilentlyContinue
if ($docker) {
    Write-Host "[3/4] Windows docker CLI 확인: $($docker.Source)"
} else {
    Write-Host "[3/4] Windows docker CLI 없음" -ForegroundColor Yellow
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
            # PATH 갱신은 새 프로세스부터라, 아래 [4/4] 검증을 위해 사용자 PATH를 현재 세션에 덧붙인다.
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

Write-Host "[4/4] 연결 검증 (127.0.0.1:2375)"

# 2단계만 재실행하는 경우 WSL이 꺼져 있을 수 있다. 자동 시작 작업과 같은 방식으로 한 번 깨운다.
# (안 깨우면 설정이 멀쩡한데도 '연결 실패'로 잘못 보고된다)
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & wsl.exe -e true 2>&1 | Out-Null
    $ErrorActionPreference = $prevEap
}

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

# 방금 깨운 WSL이면 systemd가 dockerd를 올릴 시간이 필요하다. 최대 ~10초 재시도.
$tcpOk = $false
foreach ($attempt in 1..5) {
    $tcpOk = Test-DockerTcp
    if ($tcpOk) { break }
    Start-Sleep -Seconds 1
}

if (-not $tcpOk) {
    Write-Host "      TCP 연결 실패 -- WSL이 아직 안 떠 있거나 1단계가 미적용일 수 있습니다." -ForegroundColor Yellow
    Write-Host "        1) wsl -e true          (WSL 깨우고 재시도)" -ForegroundColor Yellow
    Write-Host "        2) WSL에서: systemctl is-active docker / ss -tlnp | grep 2375" -ForegroundColor Yellow
    Write-Host "        3) 그래도 안 되면 %USERPROFILE%\.wslconfig 에 [wsl2] / networkingMode=mirrored" -ForegroundColor Yellow
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
Write-Host "  - 127.0.0.1이 WSL에 안 닿으면 %USERPROFILE%\.wslconfig 에 [wsl2] / networkingMode=mirrored 추가."
Write-Host "  - 옛 dockerd 시작 작업(예: start-dockerd-in-wsl.bat)이 있으면 비활성화/삭제하세요."
