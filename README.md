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
