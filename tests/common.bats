#!/usr/bin/env bats

setup() {
    TMP="$(mktemp -d)"
    source "${BATS_TEST_DIRNAME}/../lib/common.sh"
}
teardown() { rm -rf "$TMP"; }

@test "have: 존재하는 명령은 0" {
    run have bash
    [ "$status" -eq 0 ]
}

@test "have: 없는 명령은 1" {
    run have __nope_no_such_cmd__
    [ "$status" -ne 0 ]
}

@test "link_with_backup: 새 심링크 생성" {
    echo "src" > "$TMP/src"
    link_with_backup "$TMP/src" "$TMP/dst" "$TMP/bak"
    [ -L "$TMP/dst" ]
    [ "$(readlink -f "$TMP/dst")" = "$(readlink -f "$TMP/src")" ]
}

@test "link_with_backup: 기존 실제 파일을 백업" {
    echo "src" > "$TMP/src"
    echo "old" > "$TMP/dst"
    link_with_backup "$TMP/src" "$TMP/dst" "$TMP/bak"
    [ -L "$TMP/dst" ]
    ls "$TMP/bak"/dst.* >/dev/null
}

@test "link_with_backup: 이미 올바른 심링크면 백업 안 함(멱등)" {
    echo "src" > "$TMP/src"
    link_with_backup "$TMP/src" "$TMP/dst" "$TMP/bak"
    link_with_backup "$TMP/src" "$TMP/dst" "$TMP/bak"
    [ ! -d "$TMP/bak" ] || [ -z "$(ls -A "$TMP/bak")" ]
}

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
