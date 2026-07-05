#!/usr/bin/env bats

load ../../tests/test_helper.sh

setup() {
    setup_test_tmpdir
    mkdir -p "$TEST_TMPDIR/bin"
    PATH="$TEST_TMPDIR/bin:$BASE_TEST_ORIG_PATH"
    source "$BASE_BASH_DIR/std/lib_std.sh"
    source "$BASE_BASH_DIR/gh/lib_gh.sh"
}

create_fake_gh() {
    local script="$TEST_TMPDIR/bin/gh"

    cat > "$script"
    chmod +x "$script"
}

@test "lib_gh can be sourced more than once" {
    source "$BASE_BASH_DIR/gh/lib_gh.sh"

    [ "$(type -t gh_run)" = "function" ]
}

@test "lib_gh fails clearly when sourced without stdlib" {
    bats_run bash -c 'source "$1"; rc=$?; printf "source-rc=%s\n" "$rc"; exit "$rc"' bash "$BASE_BASH_DIR/gh/lib_gh.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"lib_gh.sh requires lib_std.sh to be sourced first"* ]]
    [[ "$output" == *"source-rc=1"* ]]
    [[ "$output" != *"command not found"* ]]
}

@test "gh_require_cli succeeds when gh is on PATH" {
    create_fake_gh <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

    capture_command gh_require_cli

    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "gh_require_cli reports missing gh with caller hint" {
    mkdir -p "$TEST_TMPDIR/no-gh-bin"

    bats_run "$BASH" -c '
        source "$1"
        source "$2"
        PATH="$3"
        gh_require_cli "$4"
    ' bash "$BASE_BASH_DIR/std/lib_std.sh" "$BASE_BASH_DIR/gh/lib_gh.sh" "$TEST_TMPDIR/no-gh-bin" "Install GitHub CLI and retry."

    [ "$status" -eq 1 ]
    [[ "$output" == *"Required command 'gh' was not found on PATH."* ]]
    [[ "$output" == *"Install GitHub CLI and retry."* ]]
}

@test "gh_auth_status_diagnostics reports bounded auth output and hint" {
    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" && "$2" == "status" ]]; then
    printf 'auth failed\n' >&2
    printf 'run login\n' >&2
    exit 4
fi
exit 0
EOF

    capture_command gh_auth_status_diagnostics "Run a custom login command."

    [ "$status" -eq 1 ]
    [[ "$output" == *"gh auth status: auth failed"* ]]
    [[ "$output" == *"gh auth status: run login"* ]]
    [[ "$output" == *"Run a custom login command."* ]]
}

@test "gh_run passes through successful gh output" {
    create_fake_gh <<'EOF'
#!/usr/bin/env bash
printf 'gh args:'
printf ' <%s>' "$@"
printf '\n'
EOF

    capture_command gh_run issue list --repo owner/repo

    [ "$status" -eq 0 ]
    [[ "$output" == *"gh args: <issue> <list> <--repo> <owner/repo>"* ]]
}

@test "gh_run reports command failure and auth diagnostics" {
    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" && "$2" == "status" ]]; then
    printf 'not logged in\n' >&2
    exit 1
fi
printf 'command failed\n' >&2
exit 7
EOF

    capture_command gh_run issue create --title Example

    [ "$status" -eq 7 ]
    [[ "$output" == *"command failed"* ]]
    [[ "$output" == *"GitHub command failed: gh issue create --title Example"* ]]
    [[ "$output" == *"gh auth status: not logged in"* ]]
    [[ "$output" == *"Run 'gh auth login -h github.com' and retry."* ]]
}
