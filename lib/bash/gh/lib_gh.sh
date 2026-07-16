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

gh_require_cli() {
    local install_hint="${1:-}"

    command -v gh >/dev/null 2>&1 || {
        log_error "Required command 'gh' was not found on PATH."
        [[ -z "$install_hint" ]] || log_error "$install_hint"
        return 1
    }
}

gh_auth_status_diagnostics() {
    local login_hint="${1:-Run 'gh auth login -h github.com' and retry.}"
    local auth_output line

    gh_require_cli || return 1

    auth_output="$(gh auth status -h github.com 2>&1)" || {
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -n "$line" ]] && log_error "gh auth status: $line"
        done <<<"$auth_output"
        [[ -z "$login_hint" ]] || log_error "$login_hint"
        return 1
    }
}

gh_report_command_failure() {
    local status="$1"
    shift
    local printable_args=""

    if (($#)); then
        printf -v printable_args '%q ' "$@"
        printable_args="${printable_args% }"
        log_error "GitHub command failed: gh $printable_args"
    else
        log_error "GitHub command failed: gh"
    fi
    gh_auth_status_diagnostics || true
    return "$status"
}

gh_run() {
    local status=0

    gh_require_cli || return 1
    gh "$@" || status=$?
    ((status == 0)) && return 0
    gh_report_command_failure "$status" "$@"
}

gh_repo_from_remote_url() {
    local __gh_remote_url="$1"
    local __gh_result_name="${2:-}"
    local __gh_parsed_repo

    if [[ -z "$__gh_remote_url" || -z "$__gh_result_name" ]]; then
        log_error "Usage: gh_repo_from_remote_url <remote_url> <result_variable_name>"
        return 1
    fi
    assert_variable_name "$__gh_result_name"
    __std_assert_writable_output__ gh_repo_from_remote_url "$__gh_result_name" || return 1

    case "$__gh_remote_url" in
        git@github.com:*.git)
            __gh_parsed_repo="${__gh_remote_url#git@github.com:}"
            __gh_parsed_repo="${__gh_parsed_repo%.git}"
            ;;
        git@github.com:*)
            __gh_parsed_repo="${__gh_remote_url#git@github.com:}"
            ;;
        https://github.com/*.git)
            __gh_parsed_repo="${__gh_remote_url#https://github.com/}"
            __gh_parsed_repo="${__gh_parsed_repo%.git}"
            ;;
        https://github.com/*)
            __gh_parsed_repo="${__gh_remote_url#https://github.com/}"
            ;;
        *)
            return 1
            ;;
    esac

    [[ "$__gh_parsed_repo" == */* && "$__gh_parsed_repo" != */*/* ]] || return 1
    printf -v "$__gh_result_name" '%s' "$__gh_parsed_repo"
}

gh_infer_repo_from_origin() {
    local __gh_infer_repo_dir="$1"
    local __gh_infer_result_name="${2:-}"
    local __gh_infer_optional=0
    local __gh_infer_repo __gh_infer_remote_url

    if [[ -z "$__gh_infer_repo_dir" || -z "$__gh_infer_result_name" ]]; then
        log_error "Usage: gh_infer_repo_from_origin <repo_dir> <result_variable_name> [--optional]"
        return 1
    fi
    assert_variable_name "$__gh_infer_result_name"
    __std_assert_writable_output__ gh_infer_repo_from_origin "$__gh_infer_result_name" || return 1

    if [[ "${3:-}" == "--optional" ]]; then
        __gh_infer_optional=1
    fi

    __gh_infer_remote_url="$(git -C "$__gh_infer_repo_dir" remote get-url origin 2>/dev/null || true)"
    if [[ -z "$__gh_infer_remote_url" ]] || ! gh_repo_from_remote_url "$__gh_infer_remote_url" __gh_infer_repo; then
        if ((__gh_infer_optional)); then
            printf -v "$__gh_infer_result_name" '%s' ""
            return 0
        fi
        log_error "Could not infer GitHub repository from '$__gh_infer_repo_dir' origin remote."
        return 1
    fi

    printf -v "$__gh_infer_result_name" '%s' "$__gh_infer_repo"
}

gh_detect_default_branch() {
    local __gh_detect_repo_dir="$1"
    local __gh_detect_result_name="${2:-}"
    local __gh_detect_branch

    if [[ -z "$__gh_detect_repo_dir" || -z "$__gh_detect_result_name" ]]; then
        log_error "Usage: gh_detect_default_branch <repo_dir> <result_variable_name>"
        return 1
    fi
    assert_variable_name "$__gh_detect_result_name"
    __std_assert_writable_output__ gh_detect_default_branch "$__gh_detect_result_name" || return 1

    if __gh_detect_branch="$(git -C "$__gh_detect_repo_dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"; then
        __gh_detect_branch="${__gh_detect_branch#origin/}"
        if [[ -n "$__gh_detect_branch" ]]; then
            printf -v "$__gh_detect_result_name" '%s' "$__gh_detect_branch"
            return 0
        fi
    fi

    if git -C "$__gh_detect_repo_dir" show-ref --verify --quiet refs/remotes/origin/main ||
        git -C "$__gh_detect_repo_dir" show-ref --verify --quiet refs/heads/main; then
        printf -v "$__gh_detect_result_name" '%s' main
        return 0
    fi

    if git -C "$__gh_detect_repo_dir" show-ref --verify --quiet refs/remotes/origin/master ||
        git -C "$__gh_detect_repo_dir" show-ref --verify --quiet refs/heads/master; then
        printf -v "$__gh_detect_result_name" '%s' master
        return 0
    fi

    return 1
}

gh_repo_default_branch() {
    local __gh_repo="$1"
    local __gh_repo_result_name="${2:-}"
    local __gh_repo_default_branch __gh_repo_status=0

    if [[ -z "$__gh_repo" || -z "$__gh_repo_result_name" ]]; then
        log_error "Usage: gh_repo_default_branch <owner/repo> <result_variable_name>"
        return 1
    fi
    assert_variable_name "$__gh_repo_result_name"
    __std_assert_writable_output__ gh_repo_default_branch "$__gh_repo_result_name" || return 1

    gh_require_cli || return 1
    __gh_repo_default_branch="$(gh repo view "$__gh_repo" --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)" || __gh_repo_status=$?
    if ((__gh_repo_status != 0)); then
        gh_report_command_failure "$__gh_repo_status" repo view "$__gh_repo" --json defaultBranchRef --jq .defaultBranchRef.name
        return $?
    fi
    if [[ -z "$__gh_repo_default_branch" ]]; then
        log_error "GitHub repository '$__gh_repo' does not report a default branch."
        return 1
    fi

    printf -v "$__gh_repo_result_name" '%s' "$__gh_repo_default_branch"
}

__gh_api_failure_retryable() {
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
    local max_attempts="${BASE_GH_API_MAX_ATTEMPTS:-2}"
    local attempt=1
    local output status delay

    gh_require_cli || return 1
    if [[ ! "$max_attempts" =~ ^[0-9]+$ ]] || ((max_attempts < 1)); then
        log_warn "BASE_GH_API_MAX_ATTEMPTS must be a positive integer; using 2."
        max_attempts=2
    fi

    while ((attempt <= max_attempts)); do
        output="$(gh api "$@" 2>&1)"
        status=$?
        if ((status == 0)); then
            [[ -z "$output" ]] || printf '%s\n' "$output"
            return 0
        fi

        if ((attempt == max_attempts)) || ! __gh_api_failure_retryable "$output"; then
            [[ -z "$output" ]] || printf '%s\n' "$output" >&2
            return "$status"
        fi

        if ((max_attempts == 2)); then
            log_warn "GitHub API call failed on attempt $attempt; retrying once."
        else
            log_warn "GitHub API call failed on attempt $attempt; retrying (attempt $((attempt + 1)) of $max_attempts)."
        fi
        delay="$(__gh_api_retry_delay_seconds "$output")"
        __std_sleep_interval__ "$delay"
        attempt=$((attempt + 1))
    done
}

gh_worktree_path_for_branch() {
    local branch="$1"
    local repo_dir="${2:-}"
    local target_ref="refs/heads/$branch"
    local line path="" ref
    local -a git_cmd=(git)

    [[ -n "$branch" ]] || {
        log_error "Usage: gh_worktree_path_for_branch <branch> [repo_dir]"
        return 1
    }

    [[ -z "$repo_dir" ]] || git_cmd=(git -C "$repo_dir")

    while IFS= read -r line; do
        case "$line" in
            "worktree "*)
                path="${line#worktree }"
                ;;
            "branch "*)
                ref="${line#branch }"
                if [[ "$ref" == "$target_ref" ]]; then
                    printf '%s\n' "$path"
                    return 0
                fi
                ;;
        esac
    done < <("${git_cmd[@]}" worktree list --porcelain)

    return 1
}

gh_list_worktree_branches() {
    local repo_dir="${1:-}"
    local line path="" branch=""
    local -a git_cmd=(git)

    [[ -z "$repo_dir" ]] || git_cmd=(git -C "$repo_dir")

    while IFS= read -r line; do
        case "$line" in
            "")
                if [[ -n "$path" && -n "$branch" ]]; then
                    branch="${branch#refs/heads/}"
                    printf '%s\t%s\n' "$path" "$branch"
                fi
                path=""
                branch=""
                ;;
            "worktree "*)
                path="${line#worktree }"
                ;;
            "branch "*)
                branch="${line#branch }"
                ;;
        esac
    done < <("${git_cmd[@]}" worktree list --porcelain; printf '\n')
}

gh_branch_upstream() {
    local repo_dir="$1"
    local branch="$2"

    if [[ -z "$repo_dir" || -z "$branch" ]]; then
        log_error "Usage: gh_branch_upstream <repo_dir> <branch>"
        return 1
    fi

    git -C "$repo_dir" for-each-ref --format='%(upstream:short)' "refs/heads/$branch"
}

gh_branch_merged_to_ref() {
    local repo_dir="$1"
    local branch="$2"
    local ref="$3"

    if [[ -z "$repo_dir" || -z "$branch" || -z "$ref" ]]; then
        log_error "Usage: gh_branch_merged_to_ref <repo_dir> <branch> <ref>"
        return 1
    fi

    git -C "$repo_dir" merge-base --is-ancestor "refs/heads/$branch" "$ref" >/dev/null 2>&1
}

gh_list_remote_branches() {
    local repo_dir="${1:-.}"
    local output ref _sha

    output="$(git -C "$repo_dir" ls-remote --heads origin)" || return 1
    while read -r _sha ref; do
        [[ "$ref" == refs/heads/* ]] || continue
        printf '%s\n' "${ref#refs/heads/}"
    done <<< "$output"
}
