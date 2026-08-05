#!/usr/bin/env bash

smoke_fail() {
    printf 'Bash logging smoke failed: %s\n' "$*" >&2
    return 1
}

smoke_assert_contains() {
    local text="$1" expected="$2" label="$3"

    if [[ "$text" != *"$expected"* ]]; then
        smoke_fail "$label did not contain '$expected'."
        return 1
    fi
    return 0
}

smoke_capture_stderr() {
    local stdout_path="$1" stderr_path="$2" label="$3"
    shift 3

    if ! "$@" >"$stdout_path" 2>"$stderr_path"; then
        smoke_fail "$label returned a failure status."
        return 1
    fi
    if [[ -s "$stdout_path" ]]; then
        smoke_fail "$label wrote to stdout instead of reserving it for program output."
        return 1
    fi
    SMOKE_CAPTURED_STDERR="$(<"$stderr_path")"
    return 0
}

smoke_file_mode() {
    local file_path="$1" mode

    if mode="$(stat -c '%a' "$file_path" 2>/dev/null)"; then
        printf '%s' "$mode"
        return 0
    fi
    stat -f '%Lp' "$file_path"
}

main() {
    local expected_major="${1-}" expected_minor="${2-}" expected_patch="${3-}"
    local script_dir repo_root smoke_dir primary_log payload_file
    local terminal_stdout terminal_stderr
    local info_output debug_output terminal_output primary_content mode
    local utc_output verbose_output

    if (($# != 0 && $# != 3)); then
        smoke_fail "usage: $0 [expected-major expected-minor expected-patch]"
        return 1
    fi

    if (($# == 3)) &&
        [[ "${BASH_VERSINFO[0]}" != "$expected_major" ||
            "${BASH_VERSINFO[1]}" != "$expected_minor" ||
            "${BASH_VERSINFO[2]}" != "$expected_patch" ]]; then
        smoke_fail "expected Bash $expected_major.$expected_minor.$expected_patch; running $BASH_VERSION."
        return 1
    fi

    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || {
        smoke_fail "unable to resolve the tests directory."
        return 1
    }
    repo_root="$(cd -- "$script_dir/.." && pwd -P)" || {
        smoke_fail "unable to resolve the repository root."
        return 1
    }

    unset BASE_BASH_LIBS_PRIMARY_LOG BASE_BASH_LIBS_LOG_DEBUG BASE_BASH_LIBS_LOG_UTC NO_COLOR
    # shellcheck source=../lib/bash/std/lib_std.sh
    if ! source "$repo_root/lib/bash/std/lib_std.sh"; then
        smoke_fail "unable to source lib_std.sh."
        return 1
    fi
    local -a smoke_args=()
    if ! base_bash_libs_init smoke_args --source "${BASH_SOURCE[0]}" --; then
        smoke_fail "unable to initialize lib_std.sh."
        return 1
    fi

    if ! base_bash_libs_std_check_bash_version; then
        smoke_fail "the running Bash did not satisfy the supported version check."
        return 1
    fi

    base_bash_libs_std_make_temp_dir smoke_dir bash42-logging-smoke || {
        smoke_fail "unable to create the smoke workspace."
        return 1
    }
    terminal_stdout="$smoke_dir/terminal.stdout"
    terminal_stderr="$smoke_dir/terminal.stderr"
    primary_log="$smoke_dir/primary.log"
    payload_file="$smoke_dir/payload.txt"

    smoke_capture_stderr "$terminal_stdout" "$terminal_stderr" "default INFO" \
        base_bash_libs_std_log_info -l base_bash_libs.smoke "default info" || return 1
    info_output="$SMOKE_CAPTURED_STDERR"
    smoke_assert_contains "$info_output" "INFO" "default INFO record" || return 1
    smoke_assert_contains "$info_output" "default info" "default INFO message" || return 1

    smoke_capture_stderr "$terminal_stdout" "$terminal_stderr" "default DEBUG" \
        base_bash_libs_std_log_debug -l base_bash_libs.smoke "hidden library debug" || return 1
    debug_output="$SMOKE_CAPTURED_STDERR"
    if [[ -n "$debug_output" ]]; then
        smoke_fail "library DEBUG was visible at the default thresholds."
        return 1
    fi
    if base_bash_libs_std_log_is_enabled -l base_bash_libs.smoke DEBUG; then
        smoke_fail "base_bash_libs_std_log_is_enabled accepted library DEBUG at the default thresholds."
        return 1
    fi

    base_bash_libs_std_set_log_level DEBUG || {
        smoke_fail "unable to enable terminal DEBUG."
        return 1
    }
    if base_bash_libs_std_log_is_enabled -l base_bash_libs.smoke DEBUG; then
        smoke_fail "terminal DEBUG bypassed the base_bash_libs INFO category gate."
        return 1
    fi

    base_bash_libs_std_set_log_category_level -l base_bash_libs.smoke DEBUG || {
        smoke_fail "unable to enable the smoke DEBUG category."
        return 1
    }
    if ! base_bash_libs_std_log_is_enabled -l base_bash_libs.smoke.child DEBUG; then
        smoke_fail "a child category did not inherit its parent DEBUG gate."
        return 1
    fi
    smoke_capture_stderr "$terminal_stdout" "$terminal_stderr" "enabled DEBUG" \
        base_bash_libs_std_log_debug -l base_bash_libs.smoke.child "visible category debug" || return 1
    debug_output="$SMOKE_CAPTURED_STDERR"
    smoke_assert_contains "$debug_output" "DEBUG" "enabled DEBUG record" || return 1
    smoke_assert_contains "$debug_output" "visible category debug" "enabled DEBUG message" || return 1

    base_bash_libs_std_set_log_level INFO || {
        smoke_fail "unable to restore terminal INFO."
        return 1
    }
    export BASE_BASH_LIBS_PRIMARY_LOG="$primary_log"

    if ! base_bash_libs_std_log_is_enabled -l base_bash_libs.smoke.child DEBUG; then
        smoke_fail "the eligible primary sink did not enable accepted DEBUG."
        return 1
    fi
    if [[ -e "$primary_log" ]]; then
        smoke_fail "base_bash_libs_std_log_is_enabled modified the primary sink."
        return 1
    fi

    smoke_capture_stderr "$terminal_stdout" "$terminal_stderr" "persistent DEBUG" \
        base_bash_libs_std_log_debug -l base_bash_libs.smoke.child "persisted debug" || return 1
    terminal_output="$SMOKE_CAPTURED_STDERR"
    if [[ -n "$terminal_output" ]]; then
        smoke_fail "persistent DEBUG leaked to the INFO terminal."
        return 1
    fi
    primary_content="$(<"$primary_log")"
    smoke_assert_contains "$primary_content" "DEBUG" "persistent DEBUG record" || return 1
    smoke_assert_contains "$primary_content" "persisted debug" "persistent DEBUG message" || return 1
    mode="$(smoke_file_mode "$primary_log")" || {
        smoke_fail "unable to read the primary-log mode."
        return 1
    }
    if [[ "$mode" != "600" ]]; then
        smoke_fail "primary log mode was $mode instead of 600."
        return 1
    fi

    base_bash_libs_std_set_log_category_level -l base_bash_libs.smoke INFO || {
        smoke_fail "unable to restore the smoke INFO category."
        return 1
    }
    if base_bash_libs_std_log_is_enabled -l base_bash_libs.smoke.child DEBUG; then
        smoke_fail "the INFO category gate did not suppress persistent DEBUG."
        return 1
    fi
    smoke_capture_stderr "$terminal_stdout" "$terminal_stderr" "blocked persistent DEBUG" \
        base_bash_libs_std_log_debug -l base_bash_libs.smoke.child "blocked persistent debug" || return 1
    if [[ -n "$SMOKE_CAPTURED_STDERR" ]]; then
        smoke_fail "the INFO category gate allowed terminal DEBUG."
        return 1
    fi
    primary_content="$(<"$primary_log")"
    if [[ "$primary_content" == *"blocked persistent debug"* ]]; then
        smoke_fail "the INFO category gate allowed a persistent DEBUG record."
        return 1
    fi

    base_bash_libs_std_set_log_category_level -l base_bash_libs.smoke DEBUG || {
        smoke_fail "unable to re-enable the smoke DEBUG category."
        return 1
    }
    printf 'persistent file contents\n' >"$payload_file" || {
        smoke_fail "unable to create the file-logging payload."
        return 1
    }
    smoke_capture_stderr "$terminal_stdout" "$terminal_stderr" "persistent DEBUG file" \
        base_bash_libs_std_log_debug_file -l base_bash_libs.smoke.child "$payload_file" || return 1
    terminal_output="$SMOKE_CAPTURED_STDERR"
    if [[ -n "$terminal_output" ]]; then
        smoke_fail "persistent DEBUG file contents leaked to the INFO terminal."
        return 1
    fi
    primary_content="$(<"$primary_log")"
    smoke_assert_contains "$primary_content" "Contents of file '$payload_file':" \
        "persistent file header" || return 1
    smoke_assert_contains "$primary_content" "persistent file contents" \
        "persistent file payload" || return 1

    export BASE_BASH_LIBS_LOG_UTC=1
    smoke_capture_stderr "$terminal_stdout" "$terminal_stderr" "UTC INFO" \
        base_bash_libs_std_log_info -l base_bash_libs.smoke "utc info" || return 1
    utc_output="$SMOKE_CAPTURED_STDERR"
    smoke_assert_contains "$utc_output" " UTC INFO" "UTC log timestamp" || return 1

    base_bash_libs_std_set_log_level VERBOSE || {
        smoke_fail "unable to enable VERBOSE compatibility."
        return 1
    }
    base_bash_libs_std_set_log_category_level -l base_bash_libs.smoke VERBOSE || {
        smoke_fail "unable to enable the VERBOSE compatibility category."
        return 1
    }
    smoke_capture_stderr "$terminal_stdout" "$terminal_stderr" "VERBOSE compatibility" \
        base_bash_libs_std_log_verbose -l base_bash_libs.smoke "compat verbose" || return 1
    verbose_output="$SMOKE_CAPTURED_STDERR"
    smoke_assert_contains "$verbose_output" "VERBOSE" "VERBOSE compatibility record" || return 1
    if [[ "$verbose_output" == *"deprecated"* ]]; then
        smoke_fail "VERBOSE compatibility emitted a runtime deprecation warning."
        return 1
    fi

    printf 'Bash logging smoke passed on Bash %s.\n' "$BASH_VERSION"
    return 0
}

main "$@"
