#!/usr/bin/env bats

setup() {
    repo_root="$(cd "${BATS_TEST_DIRNAME}/.." && pwd -P)"
    export BASE_BASH_LIBS_DIR="$repo_root/lib/bash"
    export BASE_BASH_LAUNCHER="$repo_root/bin/base-bash"
}

capture_app_streams() {
    local stdout_path="$1" stderr_path="$2"
    shift 2
    if "$@" >"$stdout_path" 2>"$stderr_path"; then
        status=0
    else
        status=$?
    fi
}

run_tty_command() {
    local command_line
    command -v script >/dev/null 2>&1 || skip "The 'script' command is required for tty tests."
    if script --version >/dev/null 2>&1; then
        printf -v command_line '%q ' "$@"
        run script -q -e -c "${command_line% }" /dev/null
    else
        run script -q /dev/null "$@"
    fi
}

@test "reference application package passes launcher smoke" {
    run "$repo_root/examples/reference-apps/verify.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"passed launcher smoke checks"* ]]
}

@test "reference application accepts application color modes through launcher" {
    run env PATH="$repo_root/bin:$PATH" BASE_BASH_LIBS_DIR="$repo_root/lib/bash" \
        "$repo_root/examples/reference-apps/ops-cli/bin/app" --color never status
    [ "$status" -eq 0 ]
    [[ "$output" == *"workspace="* ]]

    run env PATH="$repo_root/bin:$PATH" BASE_BASH_LIBS_DIR="$repo_root/lib/bash" \
        "$repo_root/examples/reference-apps/ops-cli/bin/app" --color=never status
    [ "$status" -eq 0 ]
    [[ "$output" == *"workspace="* ]]
}

@test "reference app applies color and verbosity policy to real captured and PTY streams" {
    local app="$repo_root/examples/reference-apps/ops-cli/bin/app"
    local stdout_file="$BATS_TEST_TMPDIR/app.stdout" stderr_file="$BATS_TEST_TMPDIR/app.stderr"
    local escaped

    capture_app_streams "$stdout_file" "$stderr_file" env NO_COLOR=1 \
        PATH="$repo_root/bin:$PATH" BASE_BASH_LIBS_DIR="$repo_root/lib/bash" \
        "$app" --color always --verbose status
    [ "$status" -eq 0 ]
    [[ "$(<"$stdout_file")" == *"workspace="* ]]
    [[ "$(<"$stderr_file")" == *"DEBUG"* ]]
    escaped=$'\033['
    [[ "$(<"$stderr_file")" == *"$escaped"* ]]

    capture_app_streams "$stdout_file" "$stderr_file" env -u NO_COLOR \
        PATH="$repo_root/bin:$PATH" BASE_BASH_LIBS_DIR="$repo_root/lib/bash" \
        "$app" --color auto --verbose status
    [ "$status" -eq 0 ]
    [[ "$(<"$stderr_file")" == *"DEBUG"* ]]
    [[ "$(<"$stderr_file")" != *"$escaped"* ]]

    capture_app_streams "$stdout_file" "$stderr_file" env -u NO_COLOR \
        PATH="$repo_root/bin:$PATH" BASE_BASH_LIBS_DIR="$repo_root/lib/bash" \
        "$app" --quiet status
    [ "$status" -eq 0 ]
    [[ "$(<"$stderr_file")" != *"DEBUG"* && "$(<"$stderr_file")" != *"INFO"* ]]

    run_tty_command env -u NO_COLOR PATH="$repo_root/bin:$PATH" \
        BASE_BASH_LIBS_DIR="$repo_root/lib/bash" "$app" --color auto --verbose status
    [ "$status" -eq 0 ]
    [[ "$output" == *"$escaped"* ]]

    run env PATH="$repo_root/bin:$PATH" BASE_BASH_LIBS_DIR="$repo_root/lib/bash" \
        "$app" status -- --color always
    [ "$status" -eq 2 ]
}

@test "reference application failure suites remain green" {
    for app in installer release-helper ops-cli; do
        run bats "$repo_root/examples/reference-apps/$app/tests/app.bats"
        [ "$status" -eq 0 ]
    done
}

@test "reference applications rehearse candidate and rollback boundaries" {
    run "$repo_root/examples/reference-apps/release-rehearsal.sh" \
        --candidate "$repo_root" \
        --rollback "$repo_root" \
        --report "$BATS_TEST_TMPDIR/reference-release.tsv"

    [ "$status" -eq 0 ]
    [[ "$output" == *"candidate and rollback apps=3"* ]]
    grep -F $'phase=candidate\tapp=installer\tstatus=pass' "$BATS_TEST_TMPDIR/reference-release.tsv"
    grep -F $'phase=rollback\tapp=ops-cli\tstatus=pass' "$BATS_TEST_TMPDIR/reference-release.tsv"
}
