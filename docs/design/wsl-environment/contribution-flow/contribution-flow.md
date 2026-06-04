---
feature: contribution-flow
category: wsl-environment
status: complete
created: 2026-06-04
last-updated: 2026-06-04
dependencies:
  - provisioning (setup.sh, install/70_link.sh, dotfiles/, lib/common.sh)
affects:
  - "~/.zshrc, ~/.gitconfig, ~/.p10k.zsh, ~/.config/nvim/init.vim (진입 파일 = 개인 소유로 전환)"
  - "dotfiles/ (관리 파일로 역할 전환), install/70_link.sh (심링크→인버전 주입)"
  - "hooks/pre-commit (신규), Makefile (mk contrib 그룹), setup.sh (hook 설치)"
---

# contribution-flow 설계 문서

> 한 줄 요약: 개인 환경은 자유롭게 수정하되 저장소엔 머신 종속 절대경로·개인설정이 새지 않도록, dotfile "역할 인버전" + pre-commit 누출 가드로 "개인 사용 ↔ 저장소 기여" 2-차선을 분리한다.

## 1. 배경과 동기

- provisioning(설치)은 정리됐으나 **그 이후 운영**(로컬 변경 → 저장소 반영)이 빈 공간으로 남음.
- 현재 dotfile은 심링크(`~/.zshrc` → `~/.peach/dotfiles/zshrc`)라, 사용자가 리눅스 습관대로 `~/.zshrc`를 직접 수정하면 **저장소 추적 원본이 즉시 오염**되고 `git add .` 시 개인설정이 딸려 올라감.
- 저장소가 **public** + 멀티머신 + 셀프 머지 환경 → 절대경로·이메일·머신명 누출이 곧 보안 사고이며 git 히스토리에 잔존(과거 PII 히스토리 재작성 경험 있음).

## 2. 목표와 비목표

### 목표
- GOAL-101: 사용자가 진입 파일(`~/.zshrc` 등)을 습관대로 직접 수정해도 **저장소가 오염되지 않는다.**
- GOAL-102: 절대경로·개인설정이 **커밋 전에 자동 차단·감지**된다.
- GOAL-103: "이 변경을 공유한다"가 **의도적 큐레이션 행위로 분리**되어, 불필요한 개인설정이 자연 필터된다.
- GOAL-104: 여러 머신이 **충돌 없이** 최신 공유 설정을 받는다(sync-down 공짜).

### 비목표
- NON-101: 로컬 개인 변경에 대한 검증/CI — 명시적 불필요(개인 사용은 자유).
- NON-102: CI 서버측 가드 — 소규모 운영 위해 v1 제외(D-07, 후속 업그레이드 후보).
- NON-103: 무거운 다단계 승인 PR 프로세스 — 셀프 머지 환경에 부적합.

## 3. 확정된 요구사항

- REQ-101: **역할 인버전(전 dotfile)** — 모든 관리 dotfile은 *사용자 소유 진입 파일*이 *저장소 관리 파일*을 `source`/`include` 한다. 우리는 진입 파일을 소유하지 않는다. 대상: `~/.zshrc`, `~/.gitconfig`, `~/.p10k.zsh`, `~/.config/nvim/init.vim` (D-08=2). — 우선순위: HIGH
- REQ-102: **개인 영역 비추적** — 개인 진입 파일은 저장소에 존재하지 않는다. 개인 편집은 저장소 오염을 일으키지 않는다. — HIGH
- REQ-103: **멱등 블록 주입** — setup이 진입 파일을 최초 생성하거나(부재 시), 기존 파일에 관리 블록을 append한다. 센티넬 마커(`# >>> peach >>>` / `# <<< peach <<<`)로 관리 블록만 교체하고 개인 내용은 불간섭. — HIGH
- REQ-104: **pre-commit 누출 가드** — 저장소 `hooks/pre-commit`이 staged 변경분에서 누출 패턴을 탐지·차단한다. 패턴: 홈 절대경로(`/home/<id>`), `/mnt/[cd]/...`, 이메일·회사도메인, 머신명·사설IP(`10.`/`192.168.`/`172.16–31.`), 시크릿 prefix(`AKIA`/`ghp_`/`-----BEGIN ... PRIVATE KEY-----`). 인라인 허용주석 `# peach-allow` 지원. — HIGH
- REQ-105: **가드 설치** — setup이 `~/.peach`에 `git config core.hooksPath hooks` 설정. 별도 clone은 `mk contrib install-hooks`(또는 문서 1줄)로 수동 설치. — MEDIUM
- REQ-106: **promote 워크플로우** — 개인 변경의 공유는 관리 파일로의 *의도적 큐레이션*이다. `mk contrib edit`(관리 파일을 `$EDITOR`로 열기)로 보조. 자동 diff 도구는 미채택(YAGNI). — MEDIUM
- REQ-107: **직접 push 허용** — 가드 통과 시 `main` 직접 push 가능, PR은 선택(D-03). — MEDIUM
- REQ-108: **멀티머신 sync-down** — 각 머신 `git -C ~/.peach pull` → 관리 파일 갱신. 개인 진입 파일은 불간섭. — HIGH
- REQ-109: **`.local` 하드 흡수 마이그레이션 (D-09=1)** — 인버전 적용 시 setup이 기존 `~/.zshrc.local`·`~/.gitconfig.local` 내용을 개인 진입 파일로 이전하고 `.local` 참조(source/include)를 제거한다. `.local`(zshrc/gitconfig) **완전 폐지**. ⚠️ 개인 데이터를 만지므로 이전 전 백업 + 멱등·재실행 안전 필수(PLAN 상세). `~/.peach.local.mk`는 **흡수 대상 아님** — 추적 `Makefile`에 머신 값을 주입하는 별개 패턴(직접 실행되어 인버전할 진입점 없음). — HIGH

## 4. 설계 개요

### 역할 인버전 (핵심)

```
[기존]  ~/.zshrc ──심링크──▶ ~/.peach/dotfiles/zshrc   ← 추적 = 메인(자연 편집 대상) ⇒ 오염
            └ source ~/.zshrc.local                      ← 개인(사이드카, 학습 필요)

[확정]  ~/.zshrc   ← 개인 소유 · 비추적 · 자유 편집 (자연스러운 손길)
            └ source ~/.peach/dotfiles/zshrc.shared       ← 저장소 추적. 사용자 미편집 ⇒ pull로 갱신 공짜
```

**원칙: 우리는 사용자의 진입 파일을 소유하지 않는다. 공유 콘텐츠는 진입 파일이 source/include 하는 별도 관리 파일에 둔다.**

이로써 삼각 딜레마(자연 편집 ↔ 깨끗한 repo ↔ 공짜 sync-down) 해소:
- 자연 편집 대상(`~/.zshrc`)을 개인 것으로 만들어 → `.local` **학습 비용 0**.
- 관리 파일은 사용자가 안 건드리니 깨끗 → **sync-down 공짜**.
- 공유 = 골라서 관리 파일로 옮기는 의도 행위 → **불필요한 개인설정 자연 필터**.

### 2-차선 흐름

```
🏠 개인 차선:   ~/.zshrc 등 자유 수정 → 끝 (검증·게이트 없음)
🌐 기여 차선:   관리 파일(dotfiles/*.shared)에 의도적 promote
                 → git commit (pre-commit 가드가 누출 스캔)
                 → 통과 시 main 직접 push (PR 선택)
멀티머신:        각 머신 git pull → 관리 파일 갱신, 개인 파일 불간섭
```

### 파일별 인버전 방식

| 진입 파일(개인) | 관리 파일(추적) | 연결 |
|----------------|----------------|------|
| `~/.zshrc` | `dotfiles/zshrc.shared` | `source` (instant-prompt 블록은 최상단 관리) |
| `~/.gitconfig` | `dotfiles/gitconfig.shared` | `[include] path=` |
| `~/.p10k.zsh` | `dotfiles/p10k.shared.zsh` | `source` base + 개인 override (재생성 주의) |
| `~/.config/nvim/init.vim` | `config/nvim/shared.vim` | `source` |

## 5. 의존성 맵

| 컴포넌트 | 의존 대상 | 영향받는 컴포넌트 |
|----------|-----------|------------------|
| `install/70_link.sh` | lib/common.sh, dotfiles/ | 심링크 → 인버전 블록 주입으로 전환 |
| `hooks/pre-commit` | git, lib(패턴) | 커밋 차단 |
| `setup.sh` | git | `core.hooksPath` 설정 |
| `Makefile`(mk contrib) | hooks/, $EDITOR | install-hooks, edit |

## 6. 기술 결정 및 대안 검토

| 결정 사항 | 선택 | 근거 | 검토한 대안 | 기각 사유 |
|-----------|------|------|-------------|-----------|
| dotfile 모델 | **역할 인버전** | 학습비용0 + 무오염 + sync-down 공짜 동시 달성 | (A)심링크-메인+`.local` / (B)복제본 | A=자연 편집이 추적파일 오염(규율 의존) / B=sync-down 머지비용·promote도 동일 큐레이션 |
| 누출 차단 위치 | **pre-commit hook만** | 소규모·경량 시작 | +GitHub Actions CI | 갓-clone/`--no-verify` 구멍 있으나 리스크 수용(후속 업그레이드) |
| 인버전 범위 | **전 dotfile** | 동일 규칙 일관성, init.vim도 개인화 여지 | zshrc+gitconfig만 | 일부만 적용 시 규칙 이원화 |
| 기여 출발점 | **유연**(`~/.peach` or 별도 clone) | `~/.peach`는 설치·업데이트용, 기여 환경 강제 안 함 | clone 강제 분리 | 과도한 제약 |
| promote 도구 | **수동 + `mk contrib edit`** | 큐레이션은 본질상 인간 판단 | 자동 diff/추출 도구 | YAGNI |
| `.local` 운명 (D-09) | **Hard absorb — 흡수·폐지** | 인버전이 사이드카 존재이유 제거, 학습비용0 충실 | (2)Soft 하위호환 유지 | 신규/기존 모두 `.local` 완전 제거가 일관됨(개인데이터 백업으로 위험 완화) |
| `.peach.local.mk` | **유지(별개 패턴)** | 추적 Makefile은 직접 실행 → 인버전할 진입점 없음, 머신 값 주입 필요 | 인버전 시도 | "개인 Makefile" 개념 부재 |

## 7. 제약조건과 가정

- 단일 진실 소스 = GitHub public `sangteak/wsl-bootstrap`. PII/절대경로 노출 = 보안 문제.
- `core.hooksPath`는 per-clone 로컬 설정(커밋 안 됨) → 각 clone이 개별 설치 필요.
- 가정: 자동 가드가 충분히 강하면 PR 무게를 줄일 수 있다(사용자 가설, D-03/D-07 채택 근거).
- 가정: 절대경로·이메일·머신명은 패턴으로 탐지 가능(고정밀 우선, 허용주석으로 오탐 완화).

## 8. 기술 가이드라인

- 진입 파일 블록 주입은 **센티넬 마커 기반 멱등 교체**(append-once, 개인 내용 불간섭).
- `~/.zshrc` instant-prompt 관리 블록은 **최상단**, 개인 영역은 중간, `source 관리파일`은 하단.
- `~/.p10k.zsh`는 `p10k configure` 재생성으로 source 라인 소실 가능 → 관리 base를 source하되 재설정 시 개인 override만 보존하는 방식으로 처리(PLAN 매듭).
- 가드 패턴은 고정밀부터(홈경로·`/mnt/[cd]/`·이메일·사설IP·시크릿 prefix), `# peach-allow` 인라인 예외, fail-closed-but-overridable(`--no-verify` 존재 인지). gitleaks는 선택적 업그레이드.
- **`.local` Hard absorb (D-09=1)**: setup이 기존 `~/.zshrc.local`·`~/.gitconfig.local`를 개인 진입 파일로 이전 후 참조 제거·폐지. 개인 데이터 이전이므로 **이전 전 백업 + 멱등(이미 흡수됐으면 재실행 시 no-op)** 필수. PLAN에서 이전 알고리즘·실패 롤백 명시.
- `~/.peach.local.mk`는 흡수 대상 아님 — Makefile `-include`(있으면 로드) + `?=`(미설정 시만 기본값) 조합으로 머신 값을 주입하는 별개 패턴. gitignore + `.example`만 커밋되어 인프라 식별자(AWS 프로파일·클러스터명) 미노출. 인버전 비적용(직접 실행 도구라 진입점 부재).

## 9. 구현 결과 및 일탈 사항 (2026-06-04 완료)

### 산출물 (feature/contribution-flow, 커밋 9개)
- `lib/common.sh`: `inject_block` / `ensure_managed_entry` / `absorb_local` 3종 헬퍼 (+ `tests/common.bats` 14/14)
- `dotfiles/*.shared` 분리(zshrc/gitconfig), `config/nvim/shared.vim`, `.local.example` 폐지
- `install/70_link.sh` 인버전 재작성, `install/80_nvim.sh` 인버전 반영
- `hooks/pre-commit` + `hooks/lib/leak-patterns.sh` 누출 가드 (+ `tests/guard.bats` 4/4)
- `setup.sh` `core.hooksPath` 자동 설정, `Makefile` `contrib` 그룹(install-hooks/edit)
- `README.md` 기여 흐름 섹션 + 머신종속/구조 갱신

### 설계 대비 일탈/보강
- **gitconfig.shared 빈 seam**: 원본 `dotfiles/gitconfig`에 공유 git 설정이 없고 `[include]`뿐이었음 → 인버전 후 빈 파일. 헤더 주석을 넣어 "향후 공유 alias/core 자리" seam으로 유지(개인 식별값은 개인 `~/.gitconfig`).
- **`.claude` 캐시 gitignore 앵커 수정**: 기존 `.claude/statusline-*.json` 패턴이 중간 슬래시로 루트에만 앵커되어 `docs/design/.claude/`를 못 잡음 → `**/.claude/` 로 수정 + 추적 해제.
- **nvim entry는 1회성 prepend**: `ensure_managed_entry`(교체형) 대신 마커 부재 시 1회 prepend. 관리 경로(`~/.peach`)가 안정적이라는 가정. 경로 변경 시 자동 갱신 안 됨(한계).
- 전 모듈 `SCRIPT_DIR` 컨벤션·`# shellcheck source-path=SCRIPTDIR` 통일.

### 검증 수준 (정직한 보고)
- ✅ 정적 `shellcheck -x` exit 0 (lib/install/setup/hooks 전부)
- ✅ 단위 `bats tests/` 18/18 (common 14 + guard 4) — 가드 사설IP/AWS키/`/mnt` 탐지 + 버전번호·공인IP 오탐 없음 추가 확인
- ✅ 임시 HOME e2e: 인버전(헤더 최상단·개인내용 보존·source), `.local` 흡수(+`.migrated`), git `[include]` 탭, 멱등(재실행 헤더 1개)
- ✅ 가드 라이브 차단: 실제 누출 커밋이 hook에 의해 차단됨(명확한 안내 메시지)
- ⚠️ **미수행**: 깨끗한 WSL에서 `setup.sh` 1회 전체 e2e(apt/sudo/바이너리 + 실제 셸 적용)는 본 환경에서 실행 안 함. **진짜 통합 검증 = 클린 WSL 1회.** 특히 실제 로그인 셸에서 p10k instant-prompt 순서·oh-my-zsh 로드 정상 여부는 클린 머신 확인 필요.

### 알려진 한계 (수용/후속)
- **가드 우회·미설치 노출 (D-07=1 수용)**: 로컬 hook만 → 갓-clone(hook 미설치)·`git commit --no-verify`로 우회 가능. CI 백스톱은 후속 후보.
- **p10k 재생성 충돌**: `p10k configure`가 `~/.p10k.zsh`(개인 entry)를 재생성하면 `source` 라인 소실 → `70_link` 재실행(또는 `mk` 재적용)으로 복구.
- **nvim entry 경로 비갱신**: 위 일탈 참조.

## 10. 변경 이력

| 날짜 | 변경 내용 | 영향 범위 | 상태 |
|------|-----------|-----------|------|
| 2026-06-04 | 브레인스토밍(국면 1~4): 역할 인버전 모델 + pre-commit 누출 가드 설계 확정 | dotfiles 전체, 70_link, hooks, setup, Makefile | ready-for-plan |
| 2026-06-04 | D-09=1 확정: `.local`(zshrc/gitconfig) Hard absorb 폐지(REQ-109), `~/.peach.local.mk`는 별개 패턴으로 유지 | install, setup, dotfiles | ready-for-plan |
| 2026-06-04 | 개발 완료(T1~T9): 헬퍼 3종 + dotfile 인버전 + 누출 가드 + mk contrib + README. shellcheck clean, bats 18/18, e2e·가드 라이브 검증. 클린 WSL e2e 미수행 | 전체 | 개발 완료 |
