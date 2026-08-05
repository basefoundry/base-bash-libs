#!/usr/bin/env bash

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1

# shellcheck source=/dev/null
source "$repo_root/lib/bash/std/lib_std.sh"

declare -a app_args=()
base_bash_libs_init app_args --source "${BASH_SOURCE[0]}" -- "$@"

base_bash_libs_require_version 1.0.0

workspace_dir=""
report_file=""

base_bash_libs_std_make_temp_dir workspace_dir "base-cookbook"
base_bash_libs_std_make_temp_file report_file "base-cookbook"

cleanup_marker() {
    base_bash_libs_std_log_debug "cleaning cookbook workspace: $workspace_dir"
}

base_bash_libs_std_register_cleanup_hook cleanup_marker

printf 'workspace=%s\n' "$workspace_dir" >"$report_file"
base_bash_libs_std_run --no-exit --quiet --timeout 5 test -s "$report_file"

printf_path=""
if base_bash_libs_std_command_path printf_path printf; then
    base_bash_libs_std_run --no-exit --quiet "$printf_path" 'report_file=%s\n' "$report_file"
fi

if base_bash_libs_std_function_exists cleanup_marker; then
    base_bash_libs_std_log_info "Registered cleanup hook for cookbook example."
fi
