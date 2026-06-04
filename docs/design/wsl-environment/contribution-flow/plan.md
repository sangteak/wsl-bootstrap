# contribution-flow 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** dotfile "역할 인버전" + pre-commit 누출 가드로 "개인 사용 ↔ 저장소 기여" 2-차선을 구현한다. 사용자는 `~/.zshrc` 등을 자유롭게 수정하되, 머신 종속 절대경로·개인설정은 저장소에 새지 않는다.

**Architecture:** 관리 콘텐츠는 `~/.peach/dotfiles/*.shared`(+`config/nvim/shared.vim`)에 두고, 개인 소유 entry 파일(`~/.zshrc` 등)이 절대경로로 `source`/`include` 한다. 70_link는 심링크 대신 멱등 블록주입으로 entry를 관리한다. 기존 `.local`은 entry로 흡수 후 `.migrated`로 보존(파괴 금지). pre-commit 가드는 순수 bash+grep으로 staged 추가라인의 누출 패턴을 차단한다.

**Tech Stack:** bash, GNU Make, git hooks(core.hooksPath), bats(테스트), shellcheck.

---

## File Structure

| 파일 | 역할 | 변경 |
|------|------|------|
| `lib/common.sh` | 공통 헬퍼 | `ensure_managed_entry`, `inject_block`, `absorb_local` 추가 |
| `dotfiles/zshrc` → `dotfiles/zshrc.shared` | 관리 zsh 콘텐츠 | rename + instant-prompt/`.local` source 제거 |
| `dotfiles/gitconfig` → `dotfiles/gitconfig.shared` | 관리 git 설정 | rename + `[include] .local` 제거 |
| `dotfiles/p10k.zsh` | 관리 p10k base | 유지(entry가 source) |
| `config/nvim/init.vim` → `config/nvim/shared.vim` | 관리 nvim 콘텐츠 | rename |
| `dotfiles/zshrc.local.example`, `gitconfig.local.example` | `.local` 템플릿 | **삭제**(인버전으로 폐지) |
| `install/70_link.sh` | dotfile 연결 | 심링크 → 인버전 블록주입 + `.local` 흡수 |
| `install/80_nvim.sh` | nvim 배포 | shared.vim 경로 반영 |
| `hooks/pre-commit` | 누출 가드 | **신규** |
| `hooks/lib/leak-patterns.sh` | 가드 패턴 정의 | **신규**(가드/테스트 공유) |
| `setup.sh` | 진입점 | `git config core.hooksPath hooks` 추가 |
| `Makefile` | ops 카탈로그 | `contrib` 그룹(install-hooks, edit) 추가 |
| `tests/common.bats` | 단위 테스트 | inject/absorb 테스트 추가 |
| `tests/guard.bats` | 가드 테스트 | **신규** |
| `README.md` | 문서 | 기여 흐름 섹션 추가 |

**센티넬 마커 규약:** `# >>> peach:<name> >>>` … `# <<< peach:<name> <<<` (zsh/bash), git/vim은 각 주석 문법.

---

## Task 1: `inject_block` 멱등 헬퍼 (lib/common.sh)

**Files:**
- Modify: `lib/common.sh`
- Test: `tests/common.bats`

- [ ] **Step 1: 실패 테스트 작성** — `tests/common.bats`에 추가

```bash
@test "inject_block: 신규 파일에 마커 블록 append" {
    local f="$BATS_TEST_TMPDIR/rc"
    inject_block "$f" demo "export A=1"
    grep -q "# >>> peach:demo >>>" "$f"
    grep -q "export A=1" "$f"
    grep -q "# <<< peach:demo <<<" "$f"
}

@test "inject_block: 재실행 멱등 — 블록 중복 없음" {
    local f="$BATS_TEST_TMPDIR/rc"
    inject_block "$f" demo "export A=1"
    inject_block "$f" demo "export A=2"
    [ "$(grep -c '# >>> peach:demo >>>' "$f")" -eq 1 ]
    grep -q "export A=2" "$f"
    ! grep -q "export A=1" "$f"
}

@test "inject_block: 마커 밖 개인 내용 불간섭" {
    local f="$BATS_TEST_TMPDIR/rc"
    printf 'alias me=ll\n' > "$f"
    inject_block "$f" demo "export A=1"
    grep -q "alias me=ll" "$f"
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bats tests/common.bats -f inject_block`
Expected: FAIL ("inject_block: command not found")

- [ ] **Step 3: 최소 구현** — `lib/common.sh`에 추가

```bash
# inject_block <target> <marker> <content>
# 멱등: peach:<marker> 블록이 있으면 교체, 없으면 끝에 append. 마커 밖은 불간섭.
inject_block() {
    local target="$1" marker="$2" content="$3"
    local begin="# >>> peach:${marker} >>>"
    local end="# <<< peach:${marker} <<<"
    mkdir -p "$(dirname "$target")"
    [ -f "$target" ] || : > "$target"
    if grep -qF "$begin" "$target"; then
        local tmp; tmp="$(mktemp)"
        local cfile; cfile="$(mktemp)"
        printf '%s\n' "$content" > "$cfile"
        awk -v b="$begin" -v e="$end" -v cf="$cfile" '
            $0==b { print; while ((getline line < cf) > 0) print line; close(cf); skip=1; next }
            $0==e { skip=0; print; next }
            skip { next }
            { print }
        ' "$target" > "$tmp"
        mv "$tmp" "$target"
        rm -f "$cfile"
    else
        { printf '%s\n%s\n%s\n' "$begin" "$content" "$end"; } >> "$target"
    fi
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `bats tests/common.bats -f inject_block`
Expected: PASS (3/3)

- [ ] **Step 5: shellcheck + 커밋**

Run: `shellcheck -x lib/common.sh`
```bash
git add lib/common.sh tests/common.bats
git commit -m "feat(common): inject_block 멱등 블록주입 헬퍼 추가"
```

---

## Task 2: `ensure_managed_entry` — 상단 블록 보장 (lib/common.sh)

instant-prompt는 entry **최상단**에 와야 한다. `inject_block`은 끝에 append하므로, entry 헤더(instant-prompt + source)를 **파일 맨 앞**에 멱등 보장하는 헬퍼가 필요하다.

**Files:**
- Modify: `lib/common.sh`
- Test: `tests/common.bats`

- [ ] **Step 1: 실패 테스트 작성**

```bash
@test "ensure_managed_entry: 신규 파일은 헤더가 맨 앞" {
    local f="$BATS_TEST_TMPDIR/zrc"
    ensure_managed_entry "$f" "$(printf 'INSTANT\nsource SHARED')"
    head -1 "$f" | grep -q "# >>> peach:entry >>>"
    grep -q "INSTANT" "$f"
    grep -q "source SHARED" "$f"
}

@test "ensure_managed_entry: 기존 개인 내용은 헤더 아래 보존" {
    local f="$BATS_TEST_TMPDIR/zrc"
    printf 'alias me=ll\n' > "$f"
    ensure_managed_entry "$f" "source SHARED"
    head -1 "$f" | grep -q "# >>> peach:entry >>>"
    grep -q "alias me=ll" "$f"
}

@test "ensure_managed_entry: 재실행 멱등 — 헤더 1개" {
    local f="$BATS_TEST_TMPDIR/zrc"
    ensure_managed_entry "$f" "source V1"
    ensure_managed_entry "$f" "source V2"
    [ "$(grep -c '# >>> peach:entry >>>' "$f")" -eq 1 ]
    grep -q "source V2" "$f"
    ! grep -q "source V1" "$f"
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bats tests/common.bats -f ensure_managed_entry`
Expected: FAIL

- [ ] **Step 3: 최소 구현** — `lib/common.sh`에 추가

```bash
# ensure_managed_entry <target> <header_content>
# peach:entry 헤더 블록을 파일 '맨 앞'에 멱등 보장(교체/선행 삽입). 나머지(개인 영역)는 보존.
ensure_managed_entry() {
    local target="$1" content="$2"
    local begin="# >>> peach:entry >>>"
    local end="# <<< peach:entry <<<"
    mkdir -p "$(dirname "$target")"
    [ -f "$target" ] || : > "$target"
    local body; body="$(mktemp)"
    if grep -qF "$begin" "$target"; then
        # 기존 헤더 제거한 본문만 추출
        awk -v b="$begin" -v e="$end" '
            $0==b {skip=1; next} $0==e {skip=0; next} skip{next} {print}
        ' "$target" > "$body"
    else
        cp "$target" "$body"
    fi
    local out; out="$(mktemp)"
    {
        printf '%s\n%s\n%s\n' "$begin" "$content" "$end"
        cat "$body"
    } > "$out"
    mv "$out" "$target"
    rm -f "$body"
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `bats tests/common.bats -f ensure_managed_entry`
Expected: PASS (3/3)

- [ ] **Step 5: shellcheck + 커밋**

```bash
shellcheck -x lib/common.sh
git add lib/common.sh tests/common.bats
git commit -m "feat(common): ensure_managed_entry 상단 헤더 멱등 보장 헬퍼"
```

---

## Task 3: `absorb_local` — `.local` 하드 흡수(파괴 금지) (lib/common.sh)

**Files:**
- Modify: `lib/common.sh`
- Test: `tests/common.bats`

- [ ] **Step 1: 실패 테스트 작성**

```bash
@test "absorb_local: 내용을 target에 흡수하고 .migrated로 보존" {
    local src="$BATS_TEST_TMPDIR/.zshrc.local"
    local dst="$BATS_TEST_TMPDIR/.zshrc"
    printf 'export SECRET=/home/me\n' > "$src"
    : > "$dst"
    absorb_local "$src" "$dst"
    grep -q "export SECRET=/home/me" "$dst"      # 흡수됨
    [ ! -f "$src" ]                               # 원본 이동
    [ -f "$src.migrated" ]                         # 보존됨(파괴 금지)
}

@test "absorb_local: 원본 없으면 no-op" {
    local src="$BATS_TEST_TMPDIR/none.local"
    local dst="$BATS_TEST_TMPDIR/.zshrc"; : > "$dst"
    run absorb_local "$src" "$dst"
    [ "$status" -eq 0 ]
}

@test "absorb_local: 재실행 멱등 — 중복 흡수 없음" {
    local src="$BATS_TEST_TMPDIR/.zshrc.local"
    local dst="$BATS_TEST_TMPDIR/.zshrc"
    printf 'export A=1\n' > "$src"; : > "$dst"
    absorb_local "$src" "$dst"
    absorb_local "$src" "$dst"   # 두 번째엔 src 없음 → no-op
    [ "$(grep -c 'export A=1' "$dst")" -eq 1 ]
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bats tests/common.bats -f absorb_local`
Expected: FAIL

- [ ] **Step 3: 최소 구현** — `lib/common.sh`에 추가

```bash
# absorb_local <local_file> <entry_file>
# .local 내용을 entry 끝(개인 영역)에 흡수 후 .local → .migrated 로 보존(삭제 안 함). 멱등.
absorb_local() {
    local src="$1" dst="$2"
    [ -f "$src" ] || return 0      # 이미 흡수됐거나 없음 → no-op
    mkdir -p "$(dirname "$dst")"
    [ -f "$dst" ] || : > "$dst"
    {
        printf '\n# ── absorbed from %s (peach contribution-flow) ──\n' "$(basename "$src")"
        cat "$src"
    } >> "$dst"
    mv "$src" "$src.migrated"
    log "absorb_local: $(basename "$src") → entry 흡수 + .migrated 보존"
}
```

- [ ] **Step 4: 테스트 통과 + shellcheck + 커밋**

Run: `bats tests/common.bats -f absorb_local && shellcheck -x lib/common.sh`
```bash
git add lib/common.sh tests/common.bats
git commit -m "feat(common): absorb_local — .local 하드 흡수(.migrated 보존, 멱등)"
```

---

## Task 4: dotfile 관리 파일 분리 (rename + 정리)

관리 콘텐츠를 `*.shared`로 옮기고, entry로 갈 instant-prompt와 `.local` source 라인을 제거한다.

**Files:**
- Rename: `dotfiles/zshrc` → `dotfiles/zshrc.shared`
- Rename: `dotfiles/gitconfig` → `dotfiles/gitconfig.shared`
- Rename: `config/nvim/init.vim` → `config/nvim/shared.vim`
- Delete: `dotfiles/zshrc.local.example`, `dotfiles/gitconfig.local.example`

- [ ] **Step 1: zshrc → zshrc.shared 이동 및 정리**

```bash
git mv dotfiles/zshrc dotfiles/zshrc.shared
```
편집 — `dotfiles/zshrc.shared`에서 제거:
- 1~6행 instant-prompt 블록 (entry로 이동하므로 삭제)
- `211: [ -f ~/.zshrc.local ] && source ~/.zshrc.local` (인버전으로 폐지)

> p10k.zsh source(203행)는 유지(관리 base). go PATH(208행) 유지.

- [ ] **Step 2: gitconfig → gitconfig.shared 이동 및 정리**

```bash
git mv dotfiles/gitconfig dotfiles/gitconfig.shared
```
편집 — `dotfiles/gitconfig.shared`에서 `[include] path = ~/.gitconfig.local` (5~6행) 제거. (user.name/email은 인버전 후 개인 `~/.gitconfig`가 직접 보유)

- [ ] **Step 3: nvim init.vim → shared.vim 이동**

```bash
git mv config/nvim/init.vim config/nvim/shared.vim
```

- [ ] **Step 4: 폐지된 `.example` 삭제**

```bash
git rm dotfiles/zshrc.local.example dotfiles/gitconfig.local.example
```

- [ ] **Step 5: 커밋**

```bash
git add -A
git commit -m "refactor(dotfiles): 관리 콘텐츠를 *.shared로 분리, .local source/example 폐지"
```

---

## Task 5: `install/70_link.sh` 인버전 전환

심링크 대신 entry 멱등 주입 + `.local` 흡수로 전환.

**Files:**
- Modify: `install/70_link.sh`
- Modify: `install/80_nvim.sh` (shared.vim 경로)

- [ ] **Step 1: `70_link.sh` 재작성**

```bash
#!/usr/bin/env bash
# 70_link: dotfile 역할 인버전 — 개인 entry 파일이 ~/.peach/*.shared 를 source/include.
# 심링크(구) 대신 멱등 블록주입. 개인 영역은 불간섭. 기존 .local은 흡수 후 .migrated 보존.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$HERE/../lib/common.sh"
PEACH="$HOME/.peach"

# ── zsh: instant-prompt(top) + source zshrc.shared ──
zsh_header="$(cat <<EOF
# Powerlevel10k instant prompt — 최상단 유지.
if [[ -r "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh" ]]; then
  source "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh"
fi
source "$PEACH/dotfiles/zshrc.shared"
# 아래는 개인 영역입니다 — 자유롭게 추가하세요(저장소에 올라가지 않습니다).
EOF
)"
absorb_local "$HOME/.zshrc.local" "$HOME/.zshrc"
ensure_managed_entry "$HOME/.zshrc" "$zsh_header"
log "70_link: ~/.zshrc entry 보장(인버전)"

# ── git: [include] gitconfig.shared (개인 ~/.gitconfig 소유) ──
absorb_local "$HOME/.gitconfig.local" "$HOME/.gitconfig"
git_header="$(cat <<EOF
[include]
	path = $PEACH/dotfiles/gitconfig.shared
EOF
)"
ensure_managed_entry "$HOME/.gitconfig" "$git_header"
log "70_link: ~/.gitconfig entry 보장(인버전)"

# ── p10k: 개인 ~/.p10k.zsh 가 관리 base 를 source ──
p10k_header="source \"$PEACH/dotfiles/p10k.zsh\""
ensure_managed_entry "$HOME/.p10k.zsh" "$p10k_header"
log "70_link: ~/.p10k.zsh entry 보장(인버전)"

mkdir -p "$HOME/.local/bin"
log "70_link: 완료"
```

> ⚠️ git `[include]`의 들여쓰기는 **탭**이어야 한다(heredoc 내 실제 탭 사용). p10k 재생성 충돌(`p10k configure`가 ~/.p10k.zsh 덮어씀)은 알려진 한계 — entry가 source만 보장하므로 재설정 시 `70_link` 재실행으로 복구.

- [ ] **Step 2: nvim entry는 80_nvim.sh에서 처리** — `install/80_nvim.sh` 편집

`config/nvim/init.vim` 배포 부분을 shared.vim source 방식으로 변경:
```bash
# ~/.config/nvim/init.vim (개인) 이 shared.vim 을 source
NVIM_DIR="$HOME/.config/nvim"
mkdir -p "$NVIM_DIR"
INIT="$NVIM_DIR/init.vim"
MARK="\" >>> peach:entry >>>"
if ! grep -qF "$MARK" "$INIT" 2>/dev/null; then
    { echo "$MARK";
      echo "source $HOME/.peach/config/nvim/shared.vim";
      echo "\" <<< peach:entry <<<";
      [ -f "$INIT" ] && cat "$INIT"; } > "$INIT.tmp" && mv "$INIT.tmp" "$INIT"
fi
log "80_nvim: ~/.config/nvim/init.vim entry 보장(인버전)"
```

- [ ] **Step 3: shellcheck**

Run: `shellcheck -x install/70_link.sh install/80_nvim.sh`
Expected: exit 0

- [ ] **Step 4: 임시 HOME 실동작 확인**

```bash
HOME="$(mktemp -d)" bash -c '
  source lib/common.sh
  ln -s "'"$PWD"'" "$HOME/.peach" 2>/dev/null || true
  printf "alias me=ll\n" > "$HOME/.zshrc"
  printf "export OLD=1\n" > "$HOME/.zshrc.local"
  bash install/70_link.sh
  head -1 "$HOME/.zshrc" | grep -q "peach:entry" && echo "HEADER_OK"
  grep -q "alias me=ll" "$HOME/.zshrc" && echo "PERSONAL_OK"
  grep -q "export OLD=1" "$HOME/.zshrc" && echo "ABSORB_OK"
  [ -f "$HOME/.zshrc.local.migrated" ] && echo "MIGRATED_OK"
'
```
Expected: HEADER_OK / PERSONAL_OK / ABSORB_OK / MIGRATED_OK

- [ ] **Step 5: 커밋**

```bash
git add install/70_link.sh install/80_nvim.sh
git commit -m "feat(install): 70_link/80_nvim 역할 인버전 전환(.local 흡수 포함)"
```

---

## Task 6: pre-commit 누출 가드

**Files:**
- Create: `hooks/lib/leak-patterns.sh`
- Create: `hooks/pre-commit`
- Create: `tests/guard.bats`

- [ ] **Step 1: 패턴 정의** — `hooks/lib/leak-patterns.sh`

```bash
#!/usr/bin/env bash
# 누출 탐지 정규식(가드/테스트 공유). grep -E 용. 고정밀 우선.
PEACH_LEAK_PATTERNS=(
    '/home/[A-Za-z0-9._-]+'                       # 홈 절대경로
    '/mnt/[cdCD]/'                                # Windows 드라이브 마운트
    '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'  # 이메일
    '(^|[^0-9])(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)[0-9]'  # 사설 IP
    'AKIA[0-9A-Z]{16}'                            # AWS access key
    'ghp_[A-Za-z0-9]{20,}'                        # GitHub PAT
    'BEGIN [A-Z ]*PRIVATE KEY'                    # PEM 키
)
```

- [ ] **Step 2: 실패 테스트 작성** — `tests/guard.bats`

```bash
setup() { GUARD="$BATS_TEST_DIRNAME/../hooks/pre-commit"; }

@test "guard: 홈 절대경로 탐지" {
    run bash -c 'printf "+export X=/home/me/work\n" | PEACH_GUARD_STDIN=1 "'"$GUARD"'"'
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "/home/"
}

@test "guard: 이메일 탐지" {
    run bash -c 'printf "+git config user.email a@b.com\n" | PEACH_GUARD_STDIN=1 "'"$GUARD"'"'
    [ "$status" -ne 0 ]
}

@test "guard: # peach-allow 예외" {
    run bash -c 'printf "+export X=/home/me # peach-allow\n" | PEACH_GUARD_STDIN=1 "'"$GUARD"'"'
    [ "$status" -eq 0 ]
}

@test "guard: 깨끗한 라인 통과" {
    run bash -c 'printf "+export EDITOR=nvim\n" | PEACH_GUARD_STDIN=1 "'"$GUARD"'"'
    [ "$status" -eq 0 ]
}
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `bats tests/guard.bats`
Expected: FAIL (hooks/pre-commit 없음)

- [ ] **Step 4: 가드 구현** — `hooks/pre-commit`

```bash
#!/usr/bin/env bash
# peach 누출 가드: staged 추가라인(또는 PEACH_GUARD_STDIN=1 시 stdin)에서 누출 패턴 차단.
# 우회: git commit --no-verify (의도적일 때만). 예외: 라인에 '# peach-allow'.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=hooks/lib/leak-patterns.sh
source "$HERE/lib/leak-patterns.sh"

if [ "${PEACH_GUARD_STDIN:-0}" = "1" ]; then
    added="$(cat)"
else
    added="$(git diff --cached --no-color -U0 | grep -E '^\+[^+]' || true)"
fi

violations=0
while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in *"# peach-allow"*) continue ;; esac
    for pat in "${PEACH_LEAK_PATTERNS[@]}"; do
        if printf '%s' "$line" | grep -Eq "$pat"; then
            printf '🚨 누출 의심: %s\n   패턴: %s\n' "${line#+}" "$pat" >&2
            violations=$((violations+1))
            break
        fi
    done
done <<< "$added"

if [ "$violations" -gt 0 ]; then
    printf '\n커밋 차단: %d건. 개인값은 ~/.zshrc(개인 영역)로, 공유 필요시 일반화하거나 라인 끝에 # peach-allow.\n' "$violations" >&2
    printf '의도적 우회: git commit --no-verify\n' >&2
    exit 1
fi
exit 0
```

- [ ] **Step 5: 실행권한 + 테스트 통과**

```bash
chmod +x hooks/pre-commit
bats tests/guard.bats
```
Expected: PASS (4/4)

- [ ] **Step 6: shellcheck + 커밋**

```bash
shellcheck -x hooks/pre-commit hooks/lib/leak-patterns.sh
git add hooks/ tests/guard.bats
git commit -m "feat(hooks): pre-commit 누출 가드(절대경로·이메일·IP·시크릿, peach-allow 예외)"
```

---

## Task 7: 가드 설치 + `mk contrib` 그룹

**Files:**
- Modify: `setup.sh`
- Modify: `Makefile`

- [ ] **Step 1: setup.sh에 hooksPath 설정 추가**

`setup.sh`의 self-clone(pull) 직후, install 루프 전에 추가:
```bash
# pre-commit 누출 가드 활성화(per-clone 로컬 설정)
git -C "$PEACH_DIR" config core.hooksPath hooks
log "core.hooksPath=hooks 설정(누출 가드 활성)"
```
> `PEACH_DIR`는 setup.sh 기존 변수명에 맞춘다(실제 변수 확인 후 사용).

- [ ] **Step 2: Makefile에 contrib 그룹 추가**

`.PHONY`에 `contrib-install-hooks contrib-edit` 추가. 타깃:
```makefile
##@ contrib — 저장소 기여 (mk contrib <명령>)
contrib-install-hooks: ## 이 clone에 누출 가드(pre-commit) 활성화
	git -C $(HOME)/.peach config core.hooksPath hooks 2>/dev/null || git config core.hooksPath hooks
	@echo "core.hooksPath=hooks 설정 완료(누출 가드 활성)"
contrib-edit: ## 관리 dotfile을 $EDITOR로 열기 (mk contrib edit [zshrc|gitconfig|p10k|nvim])
	@target="$(ARGS)"; case "$$target" in \
	  zshrc|"") f="$(HOME)/.peach/dotfiles/zshrc.shared" ;; \
	  gitconfig) f="$(HOME)/.peach/dotfiles/gitconfig.shared" ;; \
	  p10k) f="$(HOME)/.peach/dotfiles/p10k.zsh" ;; \
	  nvim) f="$(HOME)/.peach/config/nvim/shared.vim" ;; \
	  *) echo "알 수 없는 대상: $$target (zshrc|gitconfig|p10k|nvim)"; exit 1 ;; \
	esac; \
	$${EDITOR:-vi} "$$f"
```

- [ ] **Step 3: 검증**

```bash
shellcheck -x setup.sh
make -C . help | grep -q contrib && echo "MK_OK"
make -C . contrib-install-hooks && git config --get core.hooksPath | grep -q hooks && echo "HOOK_OK"
```
Expected: MK_OK / HOOK_OK

- [ ] **Step 4: 커밋**

```bash
git add setup.sh Makefile
git commit -m "feat(setup/mk): core.hooksPath 자동 설정 + mk contrib(install-hooks/edit)"
```

---

## Task 8: 문서 + 도메인 일탈 정리

**Files:**
- Modify: `README.md`

- [ ] **Step 1: README에 "기여 흐름" 섹션 추가**

내용(핵심만):
- 2-차선 설명: 개인(`~/.zshrc` 자유 수정, 검증 없음) ↔ 기여(관리 `*.shared`에 promote → 가드 통과 커밋 → push)
- 인버전 모델 그림(개인 entry → `source ~/.peach/dotfiles/*.shared`)
- 별도 clone 사용 시: `mk contrib install-hooks`로 가드 활성(필수)
- 가드 우회 `--no-verify`는 의도적일 때만, `# peach-allow` 인라인 예외
- `.local`은 폐지(인버전으로 흡수), `~/.peach.local.mk`는 유지(ops 머신값)

- [ ] **Step 2: 구조 표 갱신** — `hooks/`, `*.shared` 반영

- [ ] **Step 3: 커밋**

```bash
git add README.md
git commit -m "docs(README): 기여 흐름(역할 인버전 + 누출 가드) 섹션 추가"
```

---

## Task 9: 통합 검증 (clean-room 시뮬레이션)

> 진짜 통합 검증 = 깨끗한 WSL에서 `setup.sh` 1회. 여기서는 임시 HOME으로 최대한 근사.

- [ ] **Step 1: 임시 HOME end-to-end**

```bash
T="$(mktemp -d)"; HOME="$T" bash -c '
  ln -s "'"$PWD"'" "$HOME/.peach"
  source lib/common.sh
  printf "export OLD=1\n" > "$HOME/.zshrc.local"
  bash install/70_link.sh
  # 인버전 결과
  head -1 "$HOME/.zshrc" | grep -q peach:entry && echo "ZSHRC_OK"
  grep -q "source .*/zshrc.shared" "$HOME/.zshrc" && echo "SOURCE_OK"
  grep -q "export OLD=1" "$HOME/.zshrc" && [ -f "$HOME/.zshrc.local.migrated" ] && echo "ABSORB_OK"
  grep -q "gitconfig.shared" "$HOME/.gitconfig" && echo "GIT_OK"
'
```
Expected: ZSHRC_OK / SOURCE_OK / ABSORB_OK / GIT_OK

- [ ] **Step 2: 가드 라이브 차단 확인**

```bash
git config core.hooksPath hooks
printf '\nexport LEAK=/home/tester\n' >> dotfiles/zshrc.shared
git add dotfiles/zshrc.shared
git commit -m "should fail" || echo "GUARD_BLOCKED_OK"
git restore --staged dotfiles/zshrc.shared; git checkout dotfiles/zshrc.shared
```
Expected: GUARD_BLOCKED_OK

- [ ] **Step 3: 전체 정적 검사**

```bash
shellcheck -x lib/*.sh install/*.sh setup.sh hooks/pre-commit hooks/lib/*.sh
bats tests/
```
Expected: shellcheck exit 0, bats 전체 PASS

- [ ] **Step 4: 미검증 한계 기록** — 설계 문서 §9에 정직히 기록(실제 clean WSL e2e 미실행 시).

---

## Self-Review 체크
- [ ] 각 REQ(101–109)가 태스크에 매핑됨: 101→T4/T5, 102→T5, 103→T1/T2, 104→T6, 105→T7, 106→T7, 107→T8, 108→(인버전 귀결), 109→T3/T5
- [ ] 센티넬 마커명 일관(`peach:entry`, `peach:<marker>`)
- [ ] `.local` 파괴 금지(`.migrated` 보존) 전 태스크 일관
- [ ] git `[include]` 탭 들여쓰기 주의 명시
- [ ] p10k 재생성 한계 명시
