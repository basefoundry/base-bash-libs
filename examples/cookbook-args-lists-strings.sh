#!/usr/bin/env bash

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1

# shellcheck source=/dev/null
source "$repo_root/lib/bash/std/lib_std.sh"

import "$repo_root/lib/bash/arg/lib_arg.sh"
import "$repo_root/lib/bash/list/lib_list.sh"
import "$repo_root/lib/bash/str/lib_str.sh"

declare -A options=()
declare -a positionals=()
declare -a specs=(
    "verbose|flag|--verbose|-v"
    "tag|value|--tag|-t"
)

arg_parse options positionals specs -- --tag "  Release Candidate  " --verbose alpha beta

tag="${options[tag]-default}"
str_trim tag
str_lower tag

declare -a values=()
declare -a unique_values=()
summary=""
count=""

list_append values "$tag" "${positionals[@]}" "$tag"
list_unique unique_values values
list_length count unique_values
str_join summary "," unique_values

if [[ "${options[verbose]-}" == "1" ]]; then
    log_info "Cookbook parsed $count unique values."
fi

print_message "summary=$summary"
