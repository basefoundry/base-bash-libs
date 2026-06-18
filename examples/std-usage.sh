#!/usr/bin/env bash

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1

# shellcheck source=/dev/null
source "$repo_root/lib/bash/std/lib_std.sh"

import "$repo_root/lib/bash/file/lib_file.sh"

example_file="${TMPDIR:-/tmp}/base-bash-libs-example.$$"
trap 'rm -f "$example_file"' EXIT

printf 'example\n' > "$example_file"
update_file_section "$example_file" "# BEGIN base-bash-libs" "# END base-bash-libs" "managed=true"

log_info "Validated standalone Base Bash library usage."
std_run --no-exit --quiet test -f "$example_file"
print_message "example_file=$example_file"
