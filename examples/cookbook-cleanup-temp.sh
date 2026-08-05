#!/usr/bin/env bash

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1

# shellcheck source=/dev/null
source "$repo_root/lib/bash/std/lib_std.sh"

declare -a app_args=()
bl_init app_args --source "${BASH_SOURCE[0]}" -- "$@"

bl_require_version 1.0.0

workspace_dir=""
report_file=""

bl_std_make_temp_dir workspace_dir "base-cookbook"
bl_std_make_temp_file report_file "base-cookbook"

cleanup_marker() {
    bl_std_log_debug "cleaning cookbook workspace: $workspace_dir"
}

bl_std_register_cleanup_hook cleanup_marker

printf 'workspace=%s\n' "$workspace_dir" >"$report_file"
bl_std_run --no-exit --quiet --timeout 5 test -s "$report_file"

printf_path=""
if bl_std_command_path printf_path printf; then
    bl_std_run --no-exit --quiet "$printf_path" 'report_file=%s\n' "$report_file"
fi

if bl_std_function_exists cleanup_marker; then
    bl_std_log_info "Registered cleanup hook for cookbook example."
fi
