# Phase 3: 검증 (Validation) — contribution-flow

> 카테고리: wsl-environment / 기능: contribution-flow
> 국면 3 완료 시점 고정 문서. 이후 수정하지 않는다.

## 🔧 TD 기술 검토 결과

| # | 매듭 | 판단 | 가이드라인 | 리스크 |
|---|------|------|-----------|--------|
| 1 | p10k instant prompt 순서 | 정형 패턴 | 생성 `~/.zshrc`: [최상단] instant-prompt 관리 블록 → [중간] 개인 영역 → [하단] `source 관리파일`. 비출력 추가물은 실무상 안전 | 🟡 중간 |
| 2 | pre-commit hook 설치 | clone만으론 미활성 | `git config core.hooksPath hooks` + 저장소 `hooks/pre-commit`. setup이 `~/.peach`에 설정, 별도 clone은 `mk`/문서로 수동 설치 | 🟡 중간 |
| 3 | 초기 `~/.zshrc` 생성·멱등 | 표준 블록 주입 | 센티넬 마커로 관리 블록만 교체. 기존 파일 append, 개인 내용 불간섭 | 🟢 낮음 |
| 4 | promote 워크플로우 | 본질상 수동 큐레이션(합의됨) | v1 = 문서화된 의식 + 가드. `mk contrib edit`(관리 파일 `$EDITOR` 열기) 정도. 화려한 diff 도구는 YAGNI | 🟢 낮음 |
| 5 | 가드 패턴 구현 | 오탐↔미탐 균형 | 고정밀 패턴부터(홈경로·`/mnt/[cd]/`·이메일·사설IP·시크릿 prefix) + 인라인 허용주석(`# peach-allow`). gitleaks는 선택 업그레이드 | 🟡 중간 |

## 재협의/판단 항목과 최종 결정

| 항목 | 결정 | 비고 |
|------|------|------|
| **D-07 CI 백스톱** | **1 — pre-commit hook만** | 소규모 시작, 가볍게. 갓-clone/`--no-verify` 구멍은 리스크 수용(사용자 결정) |
| **D-08 인버전 범위** | **2 — 전체 dotfile 인버전** | 동일 규칙 일관성. 특히 `init.vim`도 개인 특화 여지 큼 |

## TD가 명시한 수용된 리스크 (정직한 기록)

- **가드 우회·미설치 노출 (D-07=1)**: 로컬 hook만이라 ① 갓 clone한 환경은 hook 설치 전 가드 없음, ② `git commit --no-verify` 우회 가능. public repo + 셀프 머지라 한 번 누출 시 git 히스토리에 잔존(과거 이 저장소 PII 히스토리 재작성 경험 있음). **사용자가 소규모 운영을 이유로 리스크 수용.** CI는 후속 업그레이드 후보.
- **p10k.zsh 재생성 충돌 (D-08=2)**: `p10k configure`가 `~/.p10k.zsh` 전체를 재생성 → 주입한 `source` 라인 소실. PLAN에서 "관리 base를 source + 재설정 시 개인 override 보존"으로 해소. 블로커 아님.

## 페르소나 피드백 요약 (국면 3)

- 🔧 TD: 구현 난이도 전반 낮음~중간, 블로커 없음. 약한 고리 = 매듭 2(hook 설치)와 D-07=1의 가드 공백.
- 🐧 Kernel Dev: 매듭 3·4 경량, 무게는 1·2·5.
- 🧠 Linux Expert: 적용 범위는 사용자 결정으로 전체 인버전 확정. 저개인화 파일(p10k)은 재생성 주의점만 PLAN 이월.
