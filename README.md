# wsl_configure (peach 🍑)

깨끗한 WSL(Ubuntu 24.04, WSL2)에서 zsh 셸 환경과 스크립트를 한 번에 재현하는 프로비저닝 저장소.

## 빠른 시작 (깨끗한 WSL)

```bash
curl -fsSL https://raw.githubusercontent.com/sangteak/wsl_configure/main/setup.sh | bash
```

`setup.sh`가 git/curl을 설치하고 저장소를 `~/.peach`로 clone한 뒤, 설치 모듈을 멱등하게 실행합니다.

## 수동 시작 (폴백)

```bash
sudo apt update && sudo apt install -y git curl
git clone https://github.com/sangteak/wsl_configure.git ~/.peach
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

## 머신 종속 설정

IP 등 머신마다 다른 값은 `~/.zshrc.local`에 둡니다(저장소 커밋 금지):

```bash
cp ~/.peach/dotfiles/zshrc.local.example ~/.zshrc.local
```

## 구조

| 경로 | 역할 |
|------|------|
| `setup.sh` | 진입점 (self-clone → install/* → 검증) |
| `lib/common.sh` | 공통 멱등 헬퍼 |
| `install/` | 번호순 설치 모듈 (apt→ohmyzsh→p10k→plugins→binaries→link→nvim→wsl_conf) |
| `dotfiles/` | `.zshrc`, `.p10k.zsh` 등 원본 |
| `config/nvim/` | nvim `init.vim` 원본 → `~/.config/nvim/` |
| `scripts/` | `~/.local/bin`으로 배포되는 운영 명령 |

## 개발/테스트

```bash
sudo apt install -y shellcheck bats
shellcheck -x lib/*.sh install/*.sh setup.sh
bats tests/
```
