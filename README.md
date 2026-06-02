# wsl-bootstrap (peach 🍑)

깨끗한 WSL(Ubuntu 24.04, WSL2)에서 zsh 셸 환경과 스크립트를 한 번에 재현하는 프로비저닝 저장소.

## 빠른 시작 (깨끗한 WSL)

```bash
curl -fsSL https://raw.githubusercontent.com/sangteak/wsl-bootstrap/main/setup.sh | bash
```

`setup.sh`가 git/curl을 설치하고 저장소를 `~/.peach`로 clone한 뒤, 설치 모듈을 멱등하게 실행합니다.

## 수동 시작 (폴백)

```bash
sudo apt update && sudo apt install -y git curl
git clone https://github.com/sangteak/wsl-bootstrap.git ~/.peach
bash ~/.peach/setup.sh
```

## 재적용 (업데이트)

스크립트/설정을 수정·추가한 뒤 다시 실행하면 변경분만 적용됩니다(멱등).

```bash
bash ~/.peach/setup.sh
```

## 설치 후 필수 1회 단계

`/etc/wsl.conf`(systemd, 기본 사용자)가 변경되면 Windows PowerShell에서:

```powershell
wsl --shutdown
```

후 WSL을 다시 열어야 적용됩니다.

## 터미널 폰트 (Nerd Font) — Windows 쪽 1회 설정

Powerlevel10k 프롬프트의 아이콘(화살표·git 상태 등)은 Nerd Font가 있어야
정상 표시됩니다. 폰트는 WSL이 아니라 **Windows 터미널이 렌더링**하므로,
반드시 Windows 쪽에 설치해야 합니다.

1. Nerd Font 다운로드 — 예: [Hack Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases/latest)
   (p10k 공식 권장은 MesloLGS NF. 아무 Nerd Font나 동작)
2. 압축 해제 후 `.ttf` 전체 선택 → 우클릭 → **모든 사용자용으로 설치**
3. 터미널(Windows Terminal / VS Code 등) 설정에서 폰트를 해당 Nerd Font로 변경

> 설치하지 않으면 아이콘이 네모(□)·물음표로 깨져 보입니다. zsh 기능 자체는 정상입니다.

## Windows 터미널 테마·단축키 (선택)

Windows Terminal 한정 설정입니다. 설정 → **"JSON 파일 열기"**로 `settings.json`을
열고 아래 키를 기존 구조에 **병합**합니다. (주석은 JSONC `//` 형식 — Windows Terminal에서 허용)

### 테마 + 폰트

```jsonc
{
  "profiles": {
    "defaults": {
      "colorScheme": "Monokai Dimmed",
      "font": { "face": "Hack Nerd Font" }
    }
  },
  "schemes": [
    {
      "name": "Monokai Dimmed",
      "background": "#1E1E1E",
      "foreground": "#C0C0C0",
      "cursorColor": "#FFFFFF",
      "selectionBackground": "#444444",
      "black": "#1E1E1E",
      "red": "#AC4142",
      "green": "#90A959",
      "yellow": "#F4BF75",
      "blue": "#6A9FB5",
      "purple": "#AA759F",
      "cyan": "#75B5AA",
      "white": "#B9B9B9",
      "brightBlack": "#6A6A6A",
      "brightRed": "#D28445",
      "brightGreen": "#90A959",
      "brightYellow": "#F4BF75",
      "brightBlue": "#6A9FB5",
      "brightPurple": "#AA759F",
      "brightCyan": "#75B5AA",
      "brightWhite": "#F5F5F5"
    }
  ]
}
```

### 탭 분할·포커스 단축키

AI 창 등과 나란히 쓰기 위한 분할/포커스 이동/리사이즈 키바인딩입니다.

```jsonc
{
  "actions": [
    {
      // 분할 시 띄울 프로파일 — 각자 쓰는 프로파일명으로 변경(예: WSL 배포판명)
      "command": { "action": "splitPane", "profile": "Git Bash", "split": "down" },
      "id": "User.splitPane.48EDE706"
    }
  ],
  "keybindings": [
    { "id": "Terminal.SplitPaneDown",      "keys": "alt+shift+minus" },
    { "id": "Terminal.SplitPaneRight",     "keys": "alt+shift+plus"  },
    { "id": "User.splitPane.48EDE706",     "keys": "ctrl+shift+g"    },
    { "id": "Terminal.MoveFocusDown",      "keys": "alt+down"        },
    { "id": "Terminal.MoveFocusUp",        "keys": "alt+up"          },
    { "id": "Terminal.MoveFocusLeft",      "keys": "alt+left"        },
    { "id": "Terminal.MoveFocusRight",     "keys": "alt+right"       },
    { "id": "Terminal.ResizePaneLeft",     "keys": "alt+shift+left"  },
    { "id": "Terminal.ResizePaneRight",    "keys": "alt+shift+right" },
    { "id": "Terminal.CopyToClipboard",    "keys": "ctrl+c"          },
    { "id": "Terminal.PasteFromClipboard", "keys": "ctrl+v"          },
    { "id": "Terminal.DuplicatePaneAuto",  "keys": "alt+shift+d"     }
  ]
}
```

## Docker를 Windows에서 사용 — 로컬 TCP + 자동 시작 (선택)

`setup.sh`는 docker를 **WSL 네이티브(systemd + 유닉스 소켓)**로만 구성합니다. Windows의
`docker.exe`/VSCode에서 같은 엔진을 쓰려면, **로컬 루프백 TCP**를 열고 Windows가 그걸
바라보게 합니다. 이 설정은 머신 로컬이며 저장소엔 넣지 않습니다(다른 머신에 TCP 강제 방지).

> ⚠️ TCP는 반드시 `127.0.0.1`에만 바인딩합니다. `0.0.0.0`/WSL IP는 인증 없는 root 동급
> 노출이라 피합니다. 루프백이면 로컬 호스트만 접근합니다.

### 1) WSL: systemd docker에 로컬 TCP 추가 (drop-in)

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/override.conf >/dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://127.0.0.1:2375 --containerd=/run/containerd/containerd.sock
EOF

# 레거시 SysV dockerd(/etc/init.d/docker)가 떠 있으면 멈추고 systemd로 일원화
sudo service docker stop 2>/dev/null || true
sudo systemctl daemon-reload
sudo systemctl enable --now docker
sudo systemctl restart docker

# 검증: 유닉스 소켓 + 로컬 TCP 양쪽 동작
unset DOCKER_HOST; docker ps
docker -H tcp://127.0.0.1:2375 ps
```

WSL 내부 CLI는 유닉스 소켓을 쓰므로 `~/.zshrc`/`~/.profile`에 `DOCKER_HOST`를 두지 않습니다.

### 2) Windows: 접속값 + 로그온 자동 시작

**접속값** — 사용자 환경변수:

```
DOCKER_HOST = tcp://localhost:2375
```

→ `docker.exe`·VSCode Docker 확장이 자동으로 이 엔드포인트를 사용합니다.
(WSL2 `localhostForwarding` 기본 on. 불안정하면 `%USERPROFILE%\.wslconfig` 에
`[wsl2]` / `networkingMode=mirrored` 를 주면 `127.0.0.1` 이 공유되어 확실히 닿습니다.)

**자동 시작** — WSL은 터미널을 열어야 부팅되므로, 로그온 시 깨워야 docker/TCP가 준비됩니다.
스크립트는 `D:\98_Scripts\Docker\` 에 있습니다(`start-wsl-docker.cmd` = WSL 부팅 트리거,
`start-wsl-docker.vbs` = 창 숨김 실행). 작업 스케줄러에 등록:

```cmd
schtasks /create /tn "WSL Docker Autostart" ^
  /tr "wscript.exe \"D:\98_Scripts\Docker\start-wsl-docker.vbs\"" ^
  /sc onlogon /f
```

또는 `Win+R` → `shell:startup` 폴더에 `start-wsl-docker.vbs` 바로가기를 넣습니다.

> 기존에 `service docker start`(레거시 TCP dockerd)를 띄우던 **옛 시작 작업이 있으면 제거**합니다.
> 남아 있으면 WSL IP에 2375를 다시 열어 systemd 설정과 충돌합니다.

### 재현성 (WSL 초기화 시)

| 구성 | 위치 | 초기화 후 |
|------|------|-----------|
| 시작 스크립트(.cmd/.vbs) | `D:\98_Scripts\Docker` | 살아남음 |
| 작업 스케줄러 · `DOCKER_HOST` | Windows | 살아남음 |
| systemd drop-in | WSL ext4 | **위 1) 재실행 필요** |

## 머신 종속 설정

IP 등 머신마다 다른 값은 `~/.zshrc.local`에 둡니다(저장소 커밋 금지):

```bash
cp ~/.peach/dotfiles/zshrc.local.example ~/.zshrc.local
```

git 사용자 식별자(`user.name`/`user.email`)도 머신 로컬로 분리합니다(저장소 커밋 금지):

```bash
cp ~/.peach/dotfiles/gitconfig.local.example ~/.gitconfig.local
```

ops 명령의 환경 식별자(AWS 프로파일·리전·클러스터)는 `~/.peach.local.mk`에 둡니다(저장소 커밋 금지):

```bash
cp ~/.peach/peach.local.mk.example ~/.peach.local.mk
```

## 운영 명령 (mk)

자주 쓰는 k8s/AWS 명령은 `Makefile`에 모아두고, zsh 함수 `mk`로 **어디서나** `mk <그룹> <명령> [옵션...]` 형태로 호출합니다(`dotfiles/zshrc`에 정의).

```bash
mk                 # 전체 명령 목록 (그룹별)
mk ctx             # ctx 그룹의 하위 명령 안내 (mk <TAB> 2단계 자동완성)
mk ctx eks         # kubectl 컨텍스트를 AWS EKS로 전환
mk ctx local       # minikube(로컬)로 전환
```

타깃명은 `그룹-명령`(예: `ctx-eks`)이고, `mk`가 공백 입력을 실제 타깃 목록과 대조해 `make -C ~/.peach <그룹>-<명령> [ARGS=...]`로 디스패치합니다. 환경 식별자는 위 `~/.peach.local.mk`에서 주입됩니다(저장소엔 placeholder만).

## 구조

| 경로 | 역할 |
|------|------|
| `setup.sh` | 진입점 (self-clone → install/* → 검증) |
| `lib/common.sh` | 공통 멱등 헬퍼 |
| `install/` | 번호순 설치 모듈 (apt→ohmyzsh→p10k→plugins→binaries→docker→link→nvim→wsl_conf) |
| `dotfiles/` | `.zshrc`, `.p10k.zsh` 등 원본 |
| `config/nvim/` | nvim `init.vim` 원본 → `~/.config/nvim/` |
| `Makefile` | ops 명령 카탈로그 (zsh `mk` 함수로 호출) |
| `peach.local.mk.example` | ops 환경 식별자 템플릿 → `~/.peach.local.mk` |

## 개발/테스트

```bash
sudo apt install -y shellcheck bats
shellcheck -x lib/*.sh install/*.sh setup.sh
bats tests/
```
