#!/usr/bin/env bats

load ../../tests/test_helper.sh

setup() {
    setup_test_tmpdir
    export TEST_TMPDIR
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

create_fake_git() {
    local script="$TEST_TMPDIR/bin/git"

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

@test "GitHub required-argument APIs return usage errors under every caller option combination" {
    local function_name mode

    for mode in off e u p eu ep up eup; do
        for function_name in \
            gh_report_command_failure \
            gh_repo_from_remote_url \
            gh_infer_repo_from_origin \
            gh_repo_default_branch; do
            bats_run "$BASH" -c '
                mode="$1"
                case "$mode" in *e*) set -e ;; esac
                case "$mode" in *u*) set -u ;; esac
                case "$mode" in *p*) set -o pipefail ;; esac
                source "$2"
                source "$3"
                "$4"
                rc=$?
                exit "$rc"
            ' bash "$mode" "$BASE_BASH_DIR/std/lib_std.sh" "$BASE_BASH_DIR/gh/lib_gh.sh" "$function_name"

            [ "$status" -eq 1 ]
            [[ "$output" == *"Usage:"* ]]
            [[ "$output" != *"unbound variable"* ]]
        done
    done
}

@test "GitHub optional forms reject excess arguments and invalid values" {
    capture_command gh_require_cli one two
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: gh_require_cli [install_hint]"* ]]

    capture_command gh_auth_status_diagnostics one two
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: gh_auth_status_diagnostics [login_hint]"* ]]

    capture_command gh_infer_repo_from_origin repo result --required
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: gh_infer_repo_from_origin <repo_dir> <result_variable_name> [--optional]"* ]]

    capture_command gh_report_command_failure invalid issue list
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: gh_report_command_failure <status> [gh args...]"* ]]

    capture_command gh_report_command_failure 0 issue list
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: gh_report_command_failure <status> [gh args...]"* ]]

    capture_command gh_report_command_failure 256 issue list
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: gh_report_command_failure <status> [gh args...]"* ]]
}

@test "GitHub sensitive controls fail closed before executing or echoing malformed arguments" {
    local secret="parser-canary with spaces"
    local unicode_label=$'unicode-label-canary\xe2\x80\xa8\xe2\x80\xae'
    local invocation_file="$TEST_TMPDIR/parser-invoked"

    create_fake_gh <<'EOF'
#!/usr/bin/env bash
printf 'invoked\n' > "${TEST_TMPDIR:?}/parser-invoked"
exit 0
EOF

    capture_command gh_run --sensitive "--opaque=$secret" -- issue list
    [ "$status" -eq 1 ]
    [[ "$output" == *"protected diagnostic controls must end with --"* ]]
    [[ "$output" != *"$secret"* ]]

    capture_command gh_api_with_retry --safe-display "safe API operation" -- repos/owner/repo
    [ "$status" -eq 1 ]
    [[ "$output" == *"--safe-display is valid only with --sensitive"* ]]

    capture_command gh_run --sensitive --safe-display "--token=$secret" -- issue list
    [ "$status" -eq 1 ]
    [[ "$output" == *"one non-empty printable ASCII label"* ]]
    [[ "$output" != *"$secret"* ]]

    capture_command gh_run --sensitive --safe-display "-H$secret" -- issue list
    [ "$status" -eq 1 ]
    [[ "$output" == *"one non-empty printable ASCII label"* ]]
    [[ "$output" != *"$secret"* ]]

    capture_command gh_api_with_retry --sensitive --safe-display "-fsecret=$secret" -- repos/owner/repo
    [ "$status" -eq 1 ]
    [[ "$output" == *"one non-empty printable ASCII label"* ]]
    [[ "$output" != *"$secret"* ]]

    capture_command gh_run --sensitive --safe-display "$unicode_label" -- issue list
    [ "$status" -eq 1 ]
    [[ "$output" == *"one non-empty printable ASCII label"* ]]
    [[ "$output" != *"unicode-label-canary"* ]]

    capture_command gh_report_command_failure --sensitive 77 issue list
    [ "$status" -eq 1 ]
    [[ "$output" == *"protected diagnostic controls must end with --"* ]]

    capture_command gh_report_command_failure --sensitive -- "status=$secret" issue list
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: gh_report_command_failure"* ]]
    [[ "$output" != *"$secret"* ]]

    capture_command gh_run --sensitive --safe-display $'unsafe\nparser-secret' -- issue list
    [ "$status" -eq 1 ]
    [[ "$output" == *"one non-empty printable ASCII label"* ]]
    [[ "$output" != *"parser-secret"* ]]
    [ ! -e "$invocation_file" ]
}

@test "GitHub diagnostics are independent of and preserve caller IFS" {
    local output_file="$TEST_TMPDIR/auth-diagnostics.out"
    local rc

    create_fake_gh <<'EOF'
#!/usr/bin/env bash
printf 'first diagnostic\nsecond diagnostic\n' >&2
exit 4
EOF

    IFS=:
    if gh_auth_status_diagnostics >"$output_file" 2>&1; then
        rc=0
    else
        rc=$?
    fi

    [ "$rc" -eq 1 ]
    [ "$IFS" = ":" ]
    [[ "$(cat "$output_file")" == *"gh auth status: first diagnostic"* ]]
    [[ "$(cat "$output_file")" == *"gh auth status: second diagnostic"* ]]
}

@test "gh_run preserves command status under every caller option combination" {
    local mode

    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "auth" && "${2:-}" == "status" ]]; then
    printf 'not logged in\n' >&2
    exit 1
fi
printf 'command failed\n' >&2
exit 7
EOF

    for mode in off e u p eu ep up eup; do
        bats_run "$BASH" -c '
            mode="$1"
            case "$mode" in *e*) set -e ;; esac
            case "$mode" in *u*) set -u ;; esac
            case "$mode" in *p*) set -o pipefail ;; esac
            source "$2"
            source "$3"
            PATH="$4:$PATH"
            gh_run issue list
            rc=$?
            exit "$rc"
        ' bash "$mode" "$BASE_BASH_DIR/std/lib_std.sh" "$BASE_BASH_DIR/gh/lib_gh.sh" "$TEST_TMPDIR/bin"

        [ "$status" -eq 7 ]
        [[ "$output" == *"GitHub command failed: gh issue list"* ]]
        [[ "$output" != *"unbound variable"* ]]

        bats_run "$BASH" -c '
            mode="$1"
            case "$mode" in *e*) set -e ;; esac
            case "$mode" in *u*) set -u ;; esac
            case "$mode" in *p*) set -o pipefail ;; esac
            source "$2"
            source "$3"
            PATH="$4:$PATH"
            gh_run --sensitive --safe-display "strict protected operation" -- issue list
            rc=$?
            exit "$rc"
        ' bash "$mode" "$BASE_BASH_DIR/std/lib_std.sh" "$BASE_BASH_DIR/gh/lib_gh.sh" "$TEST_TMPDIR/bin"

        [ "$status" -eq 7 ]
        [[ "$output" == *"strict protected operation [sensitive GitHub operation; arguments hidden]"* ]]
        [[ "$output" == *"(exit 7)"* ]]
        [[ "$output" != *"gh auth status: not logged in"* ]]
        [[ "$output" != *"unbound variable"* ]]
    done
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

@test "GitHub pass-by-name helpers reject readonly result variables" {
    local repo="sentinel"
    local stderr_file="$TEST_TMPDIR/gh-readonly-output.err"
    local rc

    readonly repo
    if gh_repo_from_remote_url "https://github.com/owner/project.git" repo 2>"$stderr_file"; then
        rc=0
    else
        rc=$?
    fi

    [ "$rc" -eq 1 ]
    [ "$repo" = "sentinel" ]
    [[ "$(cat "$stderr_file")" == *"result variable 'repo' is readonly"* ]]
}

@test "GitHub result helpers reject exact internal holder names before locals or mutation" {
    local -r __gh_result_name=parsed
    local -r __gh_infer_result_name=inferred
    local -r __gh_repo_result_name=defaulted
    local parsed="keep-parsed" inferred="keep-inferred" defaulted="keep-defaulted"
    local stderr_file="$TEST_TMPDIR/gh-internal-holder.err"
    local rc

    if gh_repo_from_remote_url "https://github.com/owner/project.git" __gh_result_name 2>"$stderr_file"; then
        rc=0
    else
        rc=$?
    fi
    [ "$rc" -eq 1 ]
    [ "$parsed" = "keep-parsed" ]

    if gh_infer_repo_from_origin . __gh_infer_result_name --optional 2>"$stderr_file"; then
        rc=0
    else
        rc=$?
    fi
    [ "$rc" -eq 1 ]
    [ "$inferred" = "keep-inferred" ]

    if gh_repo_default_branch owner/project __gh_repo_result_name 2>"$stderr_file"; then
        rc=0
    else
        rc=$?
    fi
    [ "$rc" -eq 1 ]
    [ "$defaulted" = "keep-defaulted" ]
    [[ "$(cat "$stderr_file")" == *"uses the reserved '__' internal namespace"* ]]
    [[ "$(cat "$stderr_file")" != *"readonly variable"* ]]
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

@test "gh_run sensitive diagnostics hide every argv form and nested auth output from all log sinks" {
    local secret="gh-run-canary with spaces"
    local primary_log="$TEST_TMPDIR/gh-run-sensitive.log"
    local received_args="$TEST_TMPDIR/gh-run-sensitive.args"
    local primary_content

    export GH_TEST_SECRET="$secret"
    BASE_CLI_PRIMARY_LOG="$primary_log"
    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "${1-}" == "auth" && "${2-}" == "status" ]]; then
    printf 'auth diagnostic exposed %s\n' "${GH_TEST_SECRET:?}" >&2
    exit 4
fi
printf '<%s>\n' "$@" > "${TEST_TMPDIR:?}/gh-run-sensitive.args"
exit 73
EOF

    capture_command gh_run --sensitive --safe-display "create protected issue" -- \
        api graphql \
        "spaced value $secret" \
        "--option=$secret" \
        --header "Authorization: Bearer $secret" \
        "https://user:$secret@github.example.test/resource" \
        --field "token=$secret"

    [ "$status" -eq 73 ]
    [[ "$output" == *"create protected issue [sensitive GitHub operation; arguments hidden]"* ]]
    [[ "$output" == *"GitHub command failed:"* ]]
    [[ "$output" == *"(exit 73)"* ]]
    [[ "$output" == *"raw auth diagnostics hidden"* ]]
    [[ "$output" == *"Run 'gh auth login -h github.com' and retry."* ]]
    [[ "$output" != *"$secret"* ]]
    [[ "$(cat "$received_args")" == *"$secret"* ]]

    primary_content="$(cat "$primary_log")"
    [[ "$primary_content" == *"create protected issue"* ]]
    [[ "$primary_content" == *"(exit 73)"* ]]
    [[ "$primary_content" == *"raw auth diagnostics hidden"* ]]
    [[ "$primary_content" != *"$secret"* ]]
}

@test "gh_run locks sensitive diagnostics against a dynamically scoped gh function" {
    local secret="dynamic-scope-gh-canary"

    gh() {
        if [[ "${1-}" == "auth" && "${2-}" == "status" ]]; then
            printf 'auth diagnostic exposed %s\n' "$secret" >&2
            return 4
        fi
        __gh_run_sensitive=0
        __gh_run_safe_display=""
        return 67
    }

    capture_command gh_run --sensitive --safe-display "protected function call" -- \
        api graphql --header "Authorization: Bearer $secret"
    unset -f gh

    [ "$status" -eq 67 ]
    [[ "$output" == *"protected function call [sensitive GitHub operation; arguments hidden]"* ]]
    [[ "$output" == *"(exit 67)"* ]]
    [[ "$output" == *"raw auth diagnostics hidden"* ]]
    [[ "$output" != *"$secret"* ]]
}

@test "gh_report_command_failure accepts control-first sensitive reporting through status 255" {
    local secret="public-reporter-canary"

    export GH_TEST_SECRET="$secret"
    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "${1-}" == "auth" && "${2-}" == "status" ]]; then
    printf 'auth diagnostic exposed %s\n' "${GH_TEST_SECRET:?}" >&2
    exit 4
fi
exit 99
EOF

    capture_command gh_report_command_failure \
        --sensitive --safe-display "publish protected release" -- \
        255 api repos/owner/repo --header "Authorization: Bearer $secret"

    [ "$status" -eq 255 ]
    [[ "$output" == *"publish protected release [sensitive GitHub operation; arguments hidden]"* ]]
    [[ "$output" == *"(exit 255)"* ]]
    [[ "$output" == *"raw auth diagnostics hidden"* ]]
    [[ "$output" != *"$secret"* ]]
    [[ "$output" != *"--header"* ]]
}

@test "gh_run reports command failure under set -e" {
    local script="$TEST_TMPDIR/gh-run-set-e.sh"

    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" && "$2" == "status" ]]; then
    printf 'not logged in\n' >&2
    exit 1
fi
printf 'command failed\n' >&2
exit 7
EOF
    cat > "$script" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "$BASE_BASH_DIR/std/lib_std.sh"
source "$BASE_BASH_DIR/gh/lib_gh.sh"
PATH="$TEST_TMPDIR/bin:$BASE_TEST_ORIG_PATH"
gh_run issue create --title Example
printf 'after\n'
EOF
    chmod +x "$script"

    bats_run bash "$script"

    [ "$status" -eq 7 ]
    [[ "$output" == *"command failed"* ]]
    [[ "$output" == *"GitHub command failed: gh issue create --title Example"* ]]
    [[ "$output" == *"gh auth status: not logged in"* ]]
    [[ "$output" != *"after"* ]]
}

@test "gh_run quotes arguments when reporting command failure" {
    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" && "$2" == "status" ]]; then
    exit 0
fi
exit 7
EOF

    bats_run gh_run issue create --title "Example Title" --body "body value"

    [ "$status" -eq 7 ]
    [[ "$output" == *"GitHub command failed: gh issue create --title Example\\ Title --body body\\ value"* ]]
    [[ "$output" == *"(exit 7)"* ]]
    [[ "$output" != *"GitHub command failed: gh issue create --title Example Title --body body value"* ]]
}

@test "gh_run returns 1 with an error when gh is not on PATH" {
    mkdir -p "$TEST_TMPDIR/no-gh-bin"

    bats_run "$BASH" -c '
        source "$1"
        source "$2"
        PATH="$3"
        gh_run issue list
    ' bash "$BASE_BASH_DIR/std/lib_std.sh" "$BASE_BASH_DIR/gh/lib_gh.sh" "$TEST_TMPDIR/no-gh-bin"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Required command 'gh' was not found on PATH."* ]]
    [[ "$output" != *"GitHub command failed"* ]]
    [[ "$output" != *"gh auth status"* ]]
}

@test "gh_repo_from_remote_url parses supported GitHub remotes" {
    local repo

    gh_repo_from_remote_url "git@github.com:owner/repo.git" repo
    [ "$repo" = "owner/repo" ]

    gh_repo_from_remote_url "git@github.com:owner/repo" repo
    [ "$repo" = "owner/repo" ]

    gh_repo_from_remote_url "ssh://git@github.com/owner/repo.git" repo
    [ "$repo" = "owner/repo" ]

    gh_repo_from_remote_url "https://github.com/owner/repo.git" repo
    [ "$repo" = "owner/repo" ]

    gh_repo_from_remote_url "https://github.com/owner/repo" repo
    [ "$repo" = "owner/repo" ]
}

@test "gh_repo_from_remote_url supports shadowing-prone output variable names" {
    local result_var=""
    local parsed_repo=""

    gh_repo_from_remote_url "https://github.com/owner/repo.git" result_var
    gh_repo_from_remote_url "git@github.com:other/project.git" parsed_repo

    [ "$result_var" = "owner/repo" ]
    [ "$parsed_repo" = "other/project" ]
}

@test "gh_repo_from_remote_url rejects non-GitHub and malformed remotes" {
    local repo="sentinel"

    bats_run gh_repo_from_remote_url "https://example.com/owner/repo.git" repo

    [ "$status" -eq 1 ]
    [ "$repo" = "sentinel" ]

    bats_run gh_repo_from_remote_url "https://github.com/owner" repo

    [ "$status" -eq 1 ]
    [ "$repo" = "sentinel" ]

    bats_run gh_repo_from_remote_url "ssh://git@github.com//repo.git" repo

    [ "$status" -eq 1 ]
    [ "$repo" = "sentinel" ]

    bats_run gh_repo_from_remote_url "https://github.com/owner/repo?query=1" repo

    [ "$status" -eq 1 ]
    [ "$repo" = "sentinel" ]
}

@test "gh_infer_repo_from_origin reads origin through git -C" {
    local repo_dir="$TEST_TMPDIR/repo"
    local repo=""

    init_git_repo "$repo_dir"
    git -C "$repo_dir" remote add origin "git@github.com:owner/repo.git"

    gh_infer_repo_from_origin "$repo_dir" repo

    [ "$repo" = "owner/repo" ]
}

@test "gh_infer_repo_from_origin supports inferred_repo as the result variable name" {
    local repo_dir="$TEST_TMPDIR/repo"
    local inferred_repo=""

    init_git_repo "$repo_dir"
    git -C "$repo_dir" remote add origin "git@github.com:owner/repo.git"

    gh_infer_repo_from_origin "$repo_dir" inferred_repo

    [ "$inferred_repo" = "owner/repo" ]
}

@test "gh_infer_repo_from_origin supports remote_url as the result variable name" {
    local repo_dir="$TEST_TMPDIR/repo"
    local remote_url=""

    init_git_repo "$repo_dir"
    git -C "$repo_dir" remote add origin "git@github.com:owner/repo.git"

    gh_infer_repo_from_origin "$repo_dir" remote_url

    [ "$remote_url" = "owner/repo" ]
}

@test "gh_infer_repo_from_origin supports its former internal parsed name as the result variable" {
    local repo_dir="$TEST_TMPDIR/repo"
    local gh_infer_parsed_repo=""

    init_git_repo "$repo_dir"
    git -C "$repo_dir" remote add origin "git@github.com:owner/repo.git"

    gh_infer_repo_from_origin "$repo_dir" gh_infer_parsed_repo

    [ "$gh_infer_parsed_repo" = "owner/repo" ]
}

@test "gh_infer_repo_from_origin returns empty success for non-GitHub remotes when optional" {
    local repo_dir="$TEST_TMPDIR/repo"
    local repo="sentinel"

    init_git_repo "$repo_dir"
    git -C "$repo_dir" remote add origin "https://example.com/owner/repo.git"

    gh_infer_repo_from_origin "$repo_dir" repo --optional

    [ "$repo" = "" ]
}

@test "gh_infer_repo_from_origin logs non-optional inference failures" {
    local repo_dir="$TEST_TMPDIR/repo"
    local repo="sentinel"

    init_git_repo "$repo_dir"
    git -C "$repo_dir" remote add origin "https://example.com/owner/repo.git"

    bats_run gh_infer_repo_from_origin "$repo_dir" repo

    [ "$status" -eq 1 ]
    [ "$repo" = "sentinel" ]
    [[ "$output" == *"Could not infer GitHub repository from '$repo_dir' origin remote."* ]]
}

@test "gh_repo_default_branch reads GitHub repository default branch" {
    local branch=""

    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "repo" && "$2" == "view" ]]; then
    printf 'develop\n'
    exit 0
fi
exit 99
EOF

    gh_repo_default_branch "owner/repo" branch

    [ "$branch" = "develop" ]
}

@test "gh_repo_default_branch supports default_branch as the result variable name" {
    local default_branch=""

    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "repo" && "$2" == "view" ]]; then
    printf 'develop\n'
    exit 0
fi
exit 99
EOF

    gh_repo_default_branch "owner/repo" default_branch

    [ "$default_branch" = "develop" ]
}

@test "gh_repo_default_branch supports remote_default_branch as the result variable name" {
    local remote_default_branch=""

    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "repo" && "$2" == "view" ]]; then
    printf 'develop\n'
    exit 0
fi
exit 99
EOF

    gh_repo_default_branch "owner/repo" remote_default_branch

    [ "$remote_default_branch" = "develop" ]
}

@test "gh_repo_default_branch supports status as the result variable name" {
    local status=""

    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "repo" && "$2" == "view" ]]; then
    printf 'develop\n'
    exit 0
fi
exit 99
EOF

    gh_repo_default_branch "owner/repo" status

    [ "$status" = "develop" ]
}

@test "gh_api_with_retry retries retryable API pressure once" {
    create_fake_gh <<'EOF'
#!/usr/bin/env bash
state_file="${TEST_TMPDIR:?}/gh-api-count"
count=0
[[ -f "$state_file" ]] && read -r count < "$state_file"
count=$((count + 1))
printf '%s\n' "$count" > "$state_file"
if ((count == 1)); then
    printf 'secondary rate limit; retry-after: 0\n' >&2
    exit 1
fi
printf 'ok\n'
EOF

    capture_command gh_api_with_retry repos/owner/repo --jq .name

    [ "$status" -eq 0 ]
    [[ "$output" == *"GitHub API call failed on attempt 1; retrying once."* ]]
    [[ "$output" == *"ok"* ]]
    [ "$(cat "$TEST_TMPDIR/gh-api-count")" = "2" ]
}

@test "gh_api_with_retry sensitive retries and final failures never replay captured secrets" {
    local secret="gh-api-canary with spaces"
    local primary_log="$TEST_TMPDIR/gh-api-sensitive.log"
    local primary_content

    export GH_TEST_SECRET="$secret"
    export BASE_CLI_PRIMARY_LOG="$primary_log"
    export BASE_GH_API_MAX_ATTEMPTS=2
    export BASE_GH_API_RETRY_DELAY_SECONDS=0
    create_fake_gh <<'EOF'
#!/usr/bin/env bash
state_file="${TEST_TMPDIR:?}/gh-api-sensitive-count"
count=0
[[ -f "$state_file" ]] && read -r count < "$state_file"
count=$((count + 1))
printf '%s\n' "$count" > "$state_file"
printf 'secondary rate limit; retry-after: 0; captured=%s\n' "${GH_TEST_SECRET:?}" >&2
exit 29
EOF

    capture_command gh_api_with_retry --sensitive --safe-display "rotate deployment key" -- \
        repos/owner/repo \
        "spaced value $secret" \
        "--option=$secret" \
        --header "Authorization: Bearer $secret" \
        "https://user:$secret@github.example.test/resource" \
        --raw-field "token=$secret"

    [ "$status" -eq 29 ]
    [ "$(cat "$TEST_TMPDIR/gh-api-sensitive-count")" = "2" ]
    [[ "$output" == *"rotate deployment key [sensitive GitHub operation; arguments hidden]"* ]]
    [[ "$output" == *"retrying once"* ]]
    [[ "$output" == *"attempt 2 of 2"* ]]
    [[ "$output" == *"exit 29"* ]]
    [[ "$output" == *"captured output hidden"* ]]
    [[ "$output" != *"$secret"* ]]

    primary_content="$(cat "$primary_log")"
    [[ "$primary_content" == *"rotate deployment key"* ]]
    [[ "$primary_content" == *"retrying once"* ]]
    [[ "$primary_content" == *"exit 29"* ]]
    [[ "$primary_content" != *"$secret"* ]]
}

@test "gh_api_with_retry sensitive success preserves functional stdout" {
    local secret="successful-api-argv-canary"

    create_fake_gh <<'EOF'
#!/usr/bin/env bash
printf '{"ok":true}\n'
EOF

    capture_command gh_api_with_retry --sensitive --safe-display "read protected API data" -- \
        repos/owner/repo --header "Authorization: Bearer $secret"

    [ "$status" -eq 0 ]
    [ "$output" = '{"ok":true}' ]
}

@test "gh_api_with_retry avoids shadowed sleep functions between retries" {
    local shadow_file="$TEST_TMPDIR/shadowed-sleep-called"

    create_fake_gh <<'EOF'
#!/usr/bin/env bash
state_file="${TEST_TMPDIR:?}/gh-api-count"
count=0
[[ -f "$state_file" ]] && read -r count < "$state_file"
count=$((count + 1))
printf '%s\n' "$count" > "$state_file"
if ((count == 1)); then
    printf 'secondary rate limit; retry-after: 0\n' >&2
    exit 1
fi
printf 'ok\n'
EOF
    sleep() {
        printf 'shadowed sleep called\n' > "$shadow_file"
        return 0
    }

    capture_command gh_api_with_retry repos/owner/repo --jq .name

    unset -f sleep
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
    [ ! -e "$shadow_file" ]
}

@test "gh_api_with_retry preserves non-retryable failures" {
    create_fake_gh <<'EOF'
#!/usr/bin/env bash
printf 'not found\n' >&2
exit 4
EOF

    capture_command gh_api_with_retry repos/owner/missing

    [ "$status" -eq 4 ]
    [[ "$output" == *"not found"* ]]
    [[ "$output" != *"retrying"* ]]
}

@test "gh_api_with_retry captures failures under set -e" {
    local script="$TEST_TMPDIR/gh-api-set-e.sh"

    create_fake_gh <<'EOF'
#!/usr/bin/env bash
printf 'not found\n' >&2
exit 4
EOF
    cat > "$script" <<EOF
#!/usr/bin/env bash
set -e
source "$BASE_BASH_DIR/std/lib_std.sh"
source "$BASE_BASH_DIR/gh/lib_gh.sh"
PATH="$TEST_TMPDIR/bin:$PATH"
gh_api_with_retry repos/owner/missing
printf 'after\n'
EOF
    chmod +x "$script"

    bats_run bash "$script"

    [ "$status" -eq 4 ]
    [[ "$output" == *"not found"* ]]
    [[ "$output" != *"after"* ]]
}
