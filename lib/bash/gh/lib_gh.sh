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

    log_error "GitHub command failed: gh $*"
    gh_auth_status_diagnostics || true
    return "$status"
}

gh_run() {
    local status

    gh_require_cli || return 1
    gh "$@"
    status=$?
    ((status == 0)) && return 0
    gh_report_command_failure "$status" "$@"
}
