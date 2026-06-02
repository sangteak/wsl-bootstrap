---
domain: wsl-environment
status: complete
created: 2026-06-01
last-updated: 2026-06-02
features:
  - provisioning (개발 완료 2026-06-02)
affects:
  - "~/.zshrc, ~/.p10k.zsh 및 기타 dotfiles"
  - "~/.local/bin (스크립트 명령 배포 경로)"
  - "~/.peach (저장소 clone 위치)"
  - "/etc/wsl.conf"
---

# wsl-environment 도메인

> WSL 셸 환경의 재현·관리를 담당하는 도메인. 단일 진실 소스 = GitHub `sangteak/wsl-bootstrap` (clone 위치 `~/.peach`).

## 시스템 개요

깨끗한 WSL(Ubuntu 24.04, WSL2)에서 `setup.sh` 한 번으로 기존 zsh 셸 환경(oh-my-zsh·powerlevel10k·플러그인·CLI 도구·dotfiles)과 스크립트 모음을 재현하고, 이후 변경분을 멱등하게 재적용한다.

### 배경
- 환경 구성이 4종 설치 방식(apt / 수동 바이너리 / git clone / 설치 스크립트)으로 혼재.
- dotfiles는 홈(`~`)에, 스크립트는 `/mnt/d/98_Scripts`에 분산 → 재현·버전관리 어려움.
- 새 WSL 설치 시 전부 소실 → "한 번에 재현 + 스크립트 버전관리" 필요.

### 목표 / 비목표
- GOAL-001: `setup` 1회로 셸 환경 전체 재현.
- GOAL-002: 멱등 — 재실행 시 기존 skip, 변경/추가분만 적용.
- GOAL-003: GitHub 저장소를 단일 진실 소스로.
- GOAL-004: 스크립트를 `.sh` 없이 일반 명령처럼 호출.
- GOAL-005: 재현 결과가 현재 동작 환경과 동등함을 검증 단계로 보장.
- NON-001: `wsl --export/--import` 이미지 복원 방식 미채택(블랙박스 회피).
- NON-002: 기존 k8s/agones/openmatch **배포** 스크립트(`98_Scripts/.../setup/*.sh`) 재작성/이관 범위 밖.
- NON-003: Docker 데몬(Windows측 dockerd) 구동 자체 범위 밖.

## 정책 / 확정 요구사항

- REQ-001: 저장소를 `~/.peach`(ext4)로 clone 후 홈으로 심링크.
- REQ-002: dotfiles 심링크(`ln -sfn`), 기존 파일은 `~/.peach-backup/`로 대피.
- REQ-003: 스크립트 명령화 — `scripts/<name>.sh` → `~/.local/bin/<name>`(.sh 제거). 분류는 flat 시작.
- REQ-004: 멱등 설치 모듈 `install/*.sh`, 공통 헬퍼는 `lib/common.sh`로 통일.
- REQ-005: 최신 설치 기본. `versions.env`는 빈 seam(핀 로직 v2 보류, YAGNI).
- REQ-006: 머신 종속값은 `~/.zshrc.local` 분리, 저장소엔 `zshrc.local.example`.
- REQ-007: 기본 셸 전환 — `chsh -s zsh` 시도 → 실패 시 `~/.bashrc`에 `exec zsh` 폴백.
- REQ-008: `/etc/wsl.conf` 멱등 생성(systemd=true, default user) + `wsl --shutdown` 안내.
- REQ-009: 설치 후 검증(zsh 로드·도구 `--version`·p10k 로드).
- REQ-010: 기존 스크립트 선별 이관 + shebang 정상화.
- REQ-011: 진입점 self-clone — `setup.sh`가 git/curl 확보 → `~/.peach` clone/pull → exec → `install/*`. 원격 `curl | bash` 부트스트랩.
- REQ-012: nvim 생태계 재현 — `config/nvim/init.vim` 배포(중첩경로), vim-plug 부트스트랩 + headless PlugInstall(플러그인 11개), apt 의존성(nodejs/npm/universal-ctags/build-essential).

## 아키텍처

### 디렉토리 구조
```
WSLConfigure/                  (= ~/.peach 로 clone됨)
├── lib/common.sh              # 공통 멱등 헬퍼: log/warn/die, have, ensure_apt, clone_or_pull, link_with_backup
├── dotfiles/                  # 홈 직속 설정 원본 (zshrc, p10k.zsh, gitconfig, zshrc.local.example)
├── config/nvim/init.vim       # → ~/.config/nvim/init.vim (중첩 경로)
├── install/                   # 멱등 설치 모듈 (각자 lib/common.sh source, 번호순 실행)
│   ├── 10_apt.sh  20_ohmyzsh.sh  30_p10k.sh  40_plugins.sh
│   ├── 50_binaries.sh  70_link.sh  80_nvim.sh  90_wsl_conf.sh
├── scripts/                   # ~/.local/bin 으로 배포될 운영 명령 (flat)
├── versions.env               # 빈 seam (핀 로직 v2)
├── setup.sh                   # 진입점 (self-clone aware)
└── README.md
```

### 실행 흐름 (setup.sh)
```
0. curl -fsSL <raw>/setup.sh | bash
1. git/curl 확보 (있으면 skip)
2. self-clone: ~/.peach 없으면 clone, 있으면 pull → exec ~/.peach/setup.sh
3. source lib/common.sh
4. for f in install/[0-9]*.sh: 번호 순서대로 멱등 실행 (실패 시 die)
5. chsh → zsh (실패 시 .bashrc exec zsh 폴백)
6. 검증 (PATH 보강 후 zsh 로드·도구·p10k·nvim 확인)
7. 안내: wsl.conf 변경 시 "wsl --shutdown 1회"
```

### 의존성 맵
| 컴포넌트 | 의존 | 영향 |
|----------|------|------|
| setup.sh | install/*, lib/common.sh | ~, /etc/wsl.conf, ~/.local/bin |
| 30_p10k / 40_plugins | git, oh-my-zsh | .zshrc 테마/플러그인 |
| 50_binaries | curl, tar | go/nvim/kubectl/helm |
| 70_link | dotfiles/, config/, scripts/ | ~/.zshrc 등, ~/.config/nvim, ~/.local/bin |
| .zshrc | ~/.zshrc.local | DOCKER_HOST 등 런타임 |

## 주요 기술 결정

| 결정 | 선택 | 근거 | 기각 대안 |
|------|------|------|-----------|
| 재현 방식 | (A) 실제 프로비저닝 | 투명·이식성 | (B) export/import 이미지(블랙박스) |
| 배포 위치 | `~/.peach`(ext4) | 셸 속도·실행비트·CRLF·이식성 | `/mnt/d` 직접(9p 오버헤드/깨짐) |
| dotfiles 연결 | 심링크 | 단일 원본, git 추적 | 복사(이중 관리) |
| 스크립트 관리 | 선별 이관 + flat | 목적 명료, 과분류 회피 | 전부 이관 / env·ops 선분류 |
| 버전 | 최신만(핀 보류) | 검증 단계가 안전망(YAGNI) | 전면 핀 / 비교 기계장치 |
| 머신 종속값 | `~/.zshrc.local` 분리 | 이식성 | 저장소 포함(새 머신 깨짐) |
| 명령화 | `.sh` 제거 심링크 | UX(`switch_aws`) | alias / .sh 노출 |
| 부트스트랩 | setup.sh 흡수(self-clone) | 부트스트랩 역설 해소 | `00_bootstrap.sh` 모듈(레이어 오류) |
| 멱등 메커니즘 | `lib/common.sh` 공통화 | 멱등 계약 통일 | 모듈별 개별 구현(불일치 버그) |

## 제약조건 / 가정
- 대상 = WSL2 + Ubuntu 24.04(apt), sudo 권한, systemd=true.
- 단일 진실 소스 = GitHub `sangteak/wsl-bootstrap`.
- git/curl은 setup 부트스트랩에서 확보.
- `wsl --shutdown`은 Windows에서 1회 수동(WSL 내부 재시작 불가).

## 기술 가이드라인
- 모든 설치 모듈 멱등(존재/버전 체크 후 skip).
- shebang `#!/usr/bin/env bash` 통일(기존 유효 shebang은 보존).
- 심링크 `ln -sfn`, 기존 파일 백업(나노초 타임스탬프).
- oh-my-zsh `RUNZSH=no CHSH=no --unattended`.
- 머신 종속값 커밋 금지 → `.example`만.
- 설치 후 검증 단계 필수(검증은 setup의 bash에서 실행되므로 go/fzf PATH 보강 필요).

## 구현 결과 (feature: provisioning, 2026-06-02 완료)

### 산출물 (main, 커밋 16개)
- `lib/common.sh` + `tests/common.bats`(bats 5/5)
- `install/` 8개 모듈(전부 shellcheck -x exit 0), `setup.sh`(self-clone+검증)
- `dotfiles/` + `config/nvim/init.vim`, `scripts/`(cmd 15개 이관+shebang 정상화), `README.md`, `versions.env`

### 설계 대비 일탈/보강
- link_with_backup 백업 타임스탬프 나노초화(충돌 방지, 코드리뷰).
- 전 모듈 shellcheck `source-path=SCRIPTDIR`로 정적분석 clean.
- setup.sh 검증 PATH 보강(`/usr/local/go/bin`·`~/.fzf/bin` — go/fzf 오탐 방지, 통합 리뷰).
- setup.sh 모듈 실패 시 `die` 명시 메시지.
- 스크립트 shebang: 유효 `#!/bin/bash`(4) 보존, 누락/깨짐(11) 정상화.

### 검증 수준 (정직한 보고)
- 정적 shellcheck -x exit 0, 단위 bats 5/5, 70_link 임시 HOME 실동작 확인.
- ⚠️ **미수행**: install 모듈의 시스템 변경(apt/sudo/바이너리)은 본 환경에서 e2e 실행 안 함. **진짜 통합 검증 = 깨끗한 WSL에서 `setup.sh` 1회 실행.**

### 알려진 한계 (후속 후보)
- `50_binaries.sh` nvim 자산명 `x86_64` 하드코딩(amd64 가정, ARM64 미지원).
- `dotfiles/zshrc`가 여전히 `~/98_Scripts/...`를 PATH에 추가 → 깨끗한 머신에선 죽은 설정(정리 후보).
- 버전 핀(versions.env 비교/skip)은 v2 보류.

## 변경 이력
| 날짜 | 변경 내용 | 상태 |
|------|-----------|------|
| 2026-06-01 | provisioning 브레인스토밍(국면 1~4) + PLAN | ready-for-plan |
| 2026-06-02 | provisioning 개발 완료 → wsl-environment 도메인으로 승격·통합 | complete |
