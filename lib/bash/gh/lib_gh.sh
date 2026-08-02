# shellcheck shell=bash
#
# lib_gh.sh - Generic GitHub CLI helpers for Bash scripts.
#

[[ -n "${__lib_gh_sourced__:-}" ]] && return 0
if [[ "${BASE_BASH_LIBS_STDLIB_LOADED:-}" != "1" ]]; then
    printf '%s\n' "Error: lib_gh.sh requires lib_std.sh to be sourced first." >&2
    return 1 2>/dev/null || exit 1
fi
readonly __lib_gh_sourced__=1

# Public callers may provide the optional install hint even though internal
# callers use the default.
# shellcheck disable=SC2120
gh_require_cli() {
    if (($# > 1)); then
        log_error -l base_bash_libs.gh "Usage: gh_require_cli [install_hint]"
        return 1
    fi

    local install_hint="${1:-}"

    command -v gh >/dev/null 2>&1 || {
        log_error -l base_bash_libs.gh "Required command 'gh' was not found on PATH."
        [[ -z "$install_hint" ]] || log_error -l base_bash_libs.gh "$install_hint"
        return 1
    }
}

__gh_sensitive_controls_usage__() {
    local __gh_controls_helper_name="${1-}"

    case "$__gh_controls_helper_name" in
        gh_report_command_failure)
            log_error -l base_bash_libs.gh \
                "Usage: gh_report_command_failure <status> [gh args...] or gh_report_command_failure --sensitive [--safe-display <label>] -- <status> [gh args...]"
            ;;
        *)
            log_error -l base_bash_libs.gh \
                "Usage: $__gh_controls_helper_name [--sensitive [--safe-display <label>] --] [gh args...]"
            ;;
    esac
}

# Parse the optional protected-diagnostic prefix without interpreting ordinary
# GitHub arguments. Once either control is present, an explicit `--` is
# required so a malformed protected call cannot accidentally render an argv.
__gh_parse_sensitive_controls__() {
    local __gh_controls_consumed_result_name="${1-}"
    local __gh_controls_sensitive_result_name="${2-}"
    local __gh_controls_display_result_name="${3-}"
    local __gh_controls_helper_name="${4-}"
    shift 4

    local __gh_controls_consumed=0 __gh_controls_sensitive=0
    local __gh_controls_safe_display="" __gh_controls_display_seen=0
    local __gh_controls_separator_seen=0

    case "${1-}" in
        --sensitive | --safe-display)
            ;;
        *)
            printf -v "$__gh_controls_consumed_result_name" '%s' 0
            printf -v "$__gh_controls_sensitive_result_name" '%s' 0
            printf -v "$__gh_controls_display_result_name" '%s' ""
            return 0
            ;;
    esac

    while (($#)); do
        case "${1-}" in
            --sensitive)
                if ((__gh_controls_sensitive)); then
                    __gh_sensitive_controls_usage__ "$__gh_controls_helper_name"
                    return 1
                fi
                __gh_controls_sensitive=1
                __gh_controls_consumed=$((__gh_controls_consumed + 1))
                shift
                ;;
            --safe-display)
                if ((__gh_controls_display_seen)) || (($# < 2)) ||
                    ! __std_is_safe_display__ "${2-}"; then
                    log_error -l base_bash_libs.gh \
                        "$__gh_controls_helper_name: --safe-display requires one non-empty printable ASCII label that does not begin with '-'."
                    return 1
                fi
                __gh_controls_safe_display="$2"
                __gh_controls_display_seen=1
                __gh_controls_consumed=$((__gh_controls_consumed + 2))
                shift 2
                ;;
            --)
                __gh_controls_separator_seen=1
                __gh_controls_consumed=$((__gh_controls_consumed + 1))
                shift
                break
                ;;
            *)
                # Do not echo the malformed token: it may itself contain a
                # credential in an option=value form.
                log_error -l base_bash_libs.gh \
                    "$__gh_controls_helper_name: protected diagnostic controls must end with -- before GitHub arguments."
                return 1
                ;;
        esac
    done

    if ((!__gh_controls_sensitive)); then
        log_error -l base_bash_libs.gh \
            "$__gh_controls_helper_name: --safe-display is valid only with --sensitive."
        return 1
    fi
    if ((!__gh_controls_separator_seen)); then
        log_error -l base_bash_libs.gh \
            "$__gh_controls_helper_name: --sensitive requires -- before GitHub arguments."
        return 1
    fi

    printf -v "$__gh_controls_consumed_result_name" '%s' "$__gh_controls_consumed"
    printf -v "$__gh_controls_sensitive_result_name" '%s' "$__gh_controls_sensitive"
    printf -v "$__gh_controls_display_result_name" '%s' "$__gh_controls_safe_display"
}

__gh_auth_status_diagnostics__() {
    local __gh_auth_sensitive="${1-0}" __gh_auth_safe_display="${2-}"
    local __gh_auth_login_hint="${3-Run 'gh auth login -h github.com' and retry.}"
    local __gh_auth_output __gh_auth_line __gh_auth_display

    gh_require_cli || return 1

    if __gh_auth_output="$(gh auth status -h github.com 2>&1)"; then
        return 0
    fi

    if ((__gh_auth_sensitive)); then
        if ! __std_render_command_display__ __gh_auth_display 1 "$__gh_auth_safe_display" \
            "[sensitive GitHub operation; arguments hidden]"; then
            __gh_auth_display="[sensitive GitHub operation; arguments hidden]"
        fi
        log_error -l base_bash_libs.gh \
            "GitHub authentication status could not be confirmed while diagnosing $__gh_auth_display; raw auth diagnostics hidden."
    else
        while IFS= read -r __gh_auth_line || [[ -n "$__gh_auth_line" ]]; do
            [[ -n "$__gh_auth_line" ]] &&
                log_error -l base_bash_libs.gh "gh auth status: $__gh_auth_line"
        done <<<"$__gh_auth_output"
    fi
    [[ -z "$__gh_auth_login_hint" ]] || log_error -l base_bash_libs.gh "$__gh_auth_login_hint"
    return 1
}

# Public callers may provide the optional login hint even though the internal
# failure reporter uses the default.
# shellcheck disable=SC2120
gh_auth_status_diagnostics() {
    if (($# > 1)); then
        log_error -l base_bash_libs.gh "Usage: gh_auth_status_diagnostics [login_hint]"
        return 1
    fi

    __gh_auth_status_diagnostics__ 0 "" "${1:-Run 'gh auth login -h github.com' and retry.}"
}

__gh_report_command_failure__() {
    local __gh_report_status="${1-1}" __gh_report_sensitive="${2-0}"
    local __gh_report_safe_display="${3-}" __gh_report_display
    shift 3

    if ! __std_render_command_display__ __gh_report_display "$__gh_report_sensitive" \
        "$__gh_report_safe_display" "[sensitive GitHub operation; arguments hidden]" gh "$@"; then
        if ((__gh_report_sensitive)); then
            __gh_report_display="[sensitive GitHub operation; arguments hidden]"
        else
            __gh_report_display=gh
        fi
    fi

    log_error -l base_bash_libs.gh \
        "GitHub command failed: $__gh_report_display (exit $__gh_report_status)"
    __gh_auth_status_diagnostics__ "$__gh_report_sensitive" "$__gh_report_safe_display" \
        "Run 'gh auth login -h github.com' and retry." || true
    return "$__gh_report_status"
}

gh_report_command_failure() {
    local __gh_report_public_consumed=0 __gh_report_public_sensitive=0
    local __gh_report_public_safe_display=""
    local __gh_report_public_status

    __gh_parse_sensitive_controls__ __gh_report_public_consumed \
        __gh_report_public_sensitive __gh_report_public_safe_display \
        gh_report_command_failure "$@" || return 1
    ((__gh_report_public_consumed == 0)) || shift "$__gh_report_public_consumed"

    if (($# < 1)); then
        __gh_sensitive_controls_usage__ gh_report_command_failure
        return 1
    fi
    __gh_report_public_status="$1"
    shift

    if [[ ! "$__gh_report_public_status" =~ ^[0-9]{1,3}$ ]]; then
        __gh_sensitive_controls_usage__ gh_report_command_failure
        return 1
    fi
    __gh_report_public_status=$((10#$__gh_report_public_status))
    if ((__gh_report_public_status < 1 || __gh_report_public_status > 255)); then
        __gh_sensitive_controls_usage__ gh_report_command_failure
        return 1
    fi

    __gh_report_command_failure__ "$__gh_report_public_status" \
        "$__gh_report_public_sensitive" "$__gh_report_public_safe_display" "$@" || true
    return "$__gh_report_public_status"
}

gh_run() {
    local __gh_run_consumed=0 __gh_run_sensitive=0 __gh_run_safe_display=""
    local __gh_run_status=0

    __gh_parse_sensitive_controls__ __gh_run_consumed __gh_run_sensitive \
        __gh_run_safe_display gh_run "$@" || return 1
    ((__gh_run_consumed == 0)) || shift "$__gh_run_consumed"
    # A caller may provide `gh` as a shell function. Lock the normalized
    # diagnostic policy before invoking it so Bash's dynamic scope cannot let
    # that function downgrade protected failure reporting.
    local -r __gh_run_locked_sensitive="$__gh_run_sensitive"
    local -r __gh_run_locked_safe_display="$__gh_run_safe_display"

    gh_require_cli || return 1
    if gh "$@"; then
        return 0
    else
        __gh_run_status=$?
    fi

    __gh_report_command_failure__ "$__gh_run_status" "$__gh_run_locked_sensitive" \
        "$__gh_run_locked_safe_display" "$@" || true
    return "$__gh_run_status"
}

__gh_parse_repo_from_remote_url__() {
    local __gh_parse_remote_url="${1-}" __gh_parse_result_name="${2-}"
    local __gh_parse_repo

    case "$__gh_parse_remote_url" in
        git@github.com:*)
            __gh_parse_repo="${__gh_parse_remote_url#git@github.com:}"
            ;;
        ssh://git@github.com/*)
            __gh_parse_repo="${__gh_parse_remote_url#ssh://git@github.com/}"
            ;;
        https://github.com/*)
            __gh_parse_repo="${__gh_parse_remote_url#https://github.com/}"
            ;;
        *)
            return 1
            ;;
    esac

    __gh_parse_repo="${__gh_parse_repo%.git}"
    [[ "$__gh_parse_repo" =~ ^[^/[:space:]?#]+/[^/[:space:]?#]+$ ]] || return 1
    printf -v "$__gh_parse_result_name" '%s' "$__gh_parse_repo"
}

gh_repo_from_remote_url() {
    if (($# != 2)); then
        log_error -l base_bash_libs.gh "Usage: gh_repo_from_remote_url <remote_url> <result_variable_name>"
        return 1
    fi
    __std_assert_public_variable_names__ gh_repo_from_remote_url "${2-}" || return 1

    local __gh_remote_url="$1"
    local __gh_result_name="$2"
    local __gh_parsed_repo

    if [[ -z "$__gh_remote_url" || -z "$__gh_result_name" ]]; then
        log_error -l base_bash_libs.gh "Usage: gh_repo_from_remote_url <remote_url> <result_variable_name>"
        return 1
    fi
    assert_variable_name "$__gh_result_name" || return 1
    __std_assert_writable_output__ gh_repo_from_remote_url "$__gh_result_name" || return 1

    __gh_parse_repo_from_remote_url__ "$__gh_remote_url" __gh_parsed_repo || return 1
    printf -v "$__gh_result_name" '%s' "$__gh_parsed_repo"
}

gh_infer_repo_from_origin() {
    if (($# < 2 || $# > 3)) || { (($# == 3)) && [[ "$3" != "--optional" ]]; }; then
        log_error -l base_bash_libs.gh "Usage: gh_infer_repo_from_origin <repo_dir> <result_variable_name> [--optional]"
        return 1
    fi
    __std_assert_public_variable_names__ gh_infer_repo_from_origin "${2-}" || return 1

    local __gh_infer_repo_dir="$1"
    local __gh_infer_result_name="$2"
    local __gh_infer_optional=0
    local __gh_infer_parsed_repo __gh_infer_remote_url

    if [[ -z "$__gh_infer_repo_dir" || -z "$__gh_infer_result_name" ]]; then
        log_error -l base_bash_libs.gh "Usage: gh_infer_repo_from_origin <repo_dir> <result_variable_name> [--optional]"
        return 1
    fi
    assert_variable_name "$__gh_infer_result_name" || return 1
    __std_assert_writable_output__ gh_infer_repo_from_origin "$__gh_infer_result_name" || return 1

    if [[ "${3:-}" == "--optional" ]]; then
        __gh_infer_optional=1
    fi

    __gh_infer_remote_url="$(git -C "$__gh_infer_repo_dir" remote get-url origin 2>/dev/null || true)"
    if [[ -z "$__gh_infer_remote_url" ]] ||
        ! __gh_parse_repo_from_remote_url__ "$__gh_infer_remote_url" __gh_infer_parsed_repo; then
        if ((__gh_infer_optional)); then
            printf -v "$__gh_infer_result_name" '%s' ""
            return 0
        fi
        log_error -l base_bash_libs.gh "Could not infer GitHub repository from '$__gh_infer_repo_dir' origin remote."
        return 1
    fi

    printf -v "$__gh_infer_result_name" '%s' "$__gh_infer_parsed_repo"
}

gh_repo_default_branch() {
    if (($# != 2)); then
        log_error -l base_bash_libs.gh "Usage: gh_repo_default_branch <owner/repo> <result_variable_name>"
        return 1
    fi
    __std_assert_public_variable_names__ gh_repo_default_branch "${2-}" || return 1

    local __gh_repo="$1"
    local __gh_repo_result_name="$2"
    local __gh_repo_default_branch __gh_repo_status=0

    if [[ -z "$__gh_repo" || -z "$__gh_repo_result_name" ]]; then
        log_error -l base_bash_libs.gh "Usage: gh_repo_default_branch <owner/repo> <result_variable_name>"
        return 1
    fi
    assert_variable_name "$__gh_repo_result_name" || return 1
    __std_assert_writable_output__ gh_repo_default_branch "$__gh_repo_result_name" || return 1

    gh_require_cli || return 1
    __gh_repo_default_branch="$(gh repo view "$__gh_repo" --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)" || __gh_repo_status=$?
    if ((__gh_repo_status != 0)); then
        gh_report_command_failure "$__gh_repo_status" repo view "$__gh_repo" --json defaultBranchRef --jq .defaultBranchRef.name
        return $?
    fi
    if [[ -z "$__gh_repo_default_branch" ]]; then
        log_error -l base_bash_libs.gh "GitHub repository '$__gh_repo' does not report a default branch."
        return 1
    fi

    printf -v "$__gh_repo_result_name" '%s' "$__gh_repo_default_branch"
}

__gh_api_failure_retryable() {
    (($# == 1)) || return 1

    local output="${1,,}"

    [[ "$output" == *"secondary rate limit"* ||
        "$output" == *"rate limit"* ||
        "$output" == *"retry-after"* ||
        "$output" == *"abuse detection"* ||
        "$output" == *"http 502"* ||
        "$output" == *"http 503"* ||
        "$output" == *"http 504"* ||
        "$output" == *"bad gateway"* ||
        "$output" == *"service unavailable"* ||
        "$output" == *"gateway timeout"* ]]
}

__gh_api_retry_delay_seconds() {
    (($# == 1)) || return 1

    local output="${1,,}"
    local configured_delay="${BASE_GH_API_RETRY_DELAY_SECONDS:-2}"

    if [[ "$output" =~ retry-after:[[:space:]]*([0-9]+) ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi

    if [[ "$configured_delay" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$configured_delay"
        return 0
    fi

    printf '%s\n' 2
}

gh_api_with_retry() {
    local __gh_api_consumed=0 __gh_api_sensitive=0 __gh_api_safe_display=""
    local __gh_api_max_attempts="${BASE_GH_API_MAX_ATTEMPTS:-2}"
    local __gh_api_attempt=1
    local __gh_api_output __gh_api_status __gh_api_delay __gh_api_display=""

    __gh_parse_sensitive_controls__ __gh_api_consumed __gh_api_sensitive \
        __gh_api_safe_display gh_api_with_retry "$@" || return 1
    ((__gh_api_consumed == 0)) || shift "$__gh_api_consumed"

    gh_require_cli || return 1
    if [[ ! "$__gh_api_max_attempts" =~ ^[0-9]+$ ]] || ((__gh_api_max_attempts < 1)); then
        log_warn -l base_bash_libs.gh "BASE_GH_API_MAX_ATTEMPTS must be a positive integer; using 2."
        __gh_api_max_attempts=2
    fi
    if ((__gh_api_sensitive)); then
        if ! __std_render_command_display__ __gh_api_display 1 "$__gh_api_safe_display" \
            "[sensitive GitHub operation; arguments hidden]" gh api "$@"; then
            __gh_api_display="[sensitive GitHub operation; arguments hidden]"
        fi
    fi

    while ((__gh_api_attempt <= __gh_api_max_attempts)); do
        if __gh_api_output="$(gh api "$@" 2>&1)"; then
            __gh_api_status=0
        else
            __gh_api_status=$?
        fi
        if ((__gh_api_status == 0)); then
            [[ -z "$__gh_api_output" ]] || printf '%s\n' "$__gh_api_output"
            return 0
        fi

        if ((__gh_api_attempt == __gh_api_max_attempts)) ||
            ! __gh_api_failure_retryable "$__gh_api_output"; then
            if ((__gh_api_sensitive)); then
                log_error -l base_bash_libs.gh \
                    "GitHub API call failed on attempt $__gh_api_attempt of $__gh_api_max_attempts: $__gh_api_display (exit $__gh_api_status; captured output hidden)."
            else
                [[ -z "$__gh_api_output" ]] || printf '%s\n' "$__gh_api_output" >&2
            fi
            return "$__gh_api_status"
        fi

        if ((__gh_api_sensitive)); then
            if ((__gh_api_max_attempts == 2)); then
                log_warn -l base_bash_libs.gh \
                    "GitHub API call failed for $__gh_api_display on attempt $__gh_api_attempt; retrying once."
            else
                log_warn -l base_bash_libs.gh \
                    "GitHub API call failed for $__gh_api_display on attempt $__gh_api_attempt; retrying (attempt $((__gh_api_attempt + 1)) of $__gh_api_max_attempts)."
            fi
        elif ((__gh_api_max_attempts == 2)); then
            log_warn -l base_bash_libs.gh \
                "GitHub API call failed on attempt $__gh_api_attempt; retrying once."
        else
            log_warn -l base_bash_libs.gh \
                "GitHub API call failed on attempt $__gh_api_attempt; retrying (attempt $((__gh_api_attempt + 1)) of $__gh_api_max_attempts)."
        fi
        __gh_api_delay="$(__gh_api_retry_delay_seconds "$__gh_api_output")"
        __std_sleep_interval__ "$__gh_api_delay"
        __gh_api_attempt=$((__gh_api_attempt + 1))
    done
}
