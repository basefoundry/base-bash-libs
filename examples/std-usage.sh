#!/usr/bin/env bash

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1

# shellcheck source=/dev/null
source "$repo_root/lib/bash/std/lib_std.sh"

declare -a app_args=()
base_bash_libs_init app_args --source "${BASH_SOURCE[0]}" -- "$@"

base_bash_libs_std_import "$repo_root/lib/bash/file/lib_file.sh"

example_file="${TMPDIR:-/tmp}/base-bash-libs-example.$$"
trap 'rm -f "$example_file"' EXIT

printf 'example\n' > "$example_file"
base_bash_libs_file_update_file_section "$example_file" "# BEGIN base-bash-libs" "# END base-bash-libs" "managed=true"

base_bash_libs_std_log_info "Validated standalone Base Bash library usage."
base_bash_libs_std_run --no-exit --quiet test -f "$example_file"
base_bash_libs_std_print_message "example_file=$example_file"
