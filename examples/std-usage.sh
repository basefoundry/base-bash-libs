#!/usr/bin/env bash

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1

# shellcheck source=/dev/null
source "$repo_root/lib/bash/std/lib_std.sh"

# shellcheck disable=SC2034 # base_init publishes into this caller-owned array by name.
declare -a app_args=()
base_init app_args --source "${BASH_SOURCE[0]}" -- "$@"

base_std_import file/lib_file.sh

example_dir=""
base_std_make_temp_dir example_dir base-bash-libs-example || exit $?
example_file="$example_dir/example"

printf 'example\n' > "$example_file"
base_file_update_file_section "$example_file" "# BEGIN base-bash-libs" "# END base-bash-libs" "managed=true"

base_std_log_info "Validated standalone Base Bash library usage."
base_std_run --no-exit --quiet test -f "$example_file"
base_std_print_message "example_file=$example_file"
