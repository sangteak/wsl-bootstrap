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
