#!/usr/bin/env bash

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1

# shellcheck source=/dev/null
source "$repo_root/lib/bash/std/lib_std.sh"

declare -a app_args=()
bl_init app_args --source "${BASH_SOURCE[0]}" -- "$@"

bl_std_import "$repo_root/lib/bash/arg/lib_arg.sh"
bl_std_import "$repo_root/lib/bash/list/lib_list.sh"
bl_std_import "$repo_root/lib/bash/str/lib_str.sh"

declare -A options=()
declare -a positionals=()
# Passed by name to bl_arg_parse.
# shellcheck disable=SC2034
declare -a specs=(
    "verbose|flag|--verbose|-v"
    "tag|value|--tag|-t"
)

bl_arg_parse options positionals specs -- --tag "  Release Candidate  " --verbose alpha beta

tag="${options[tag]-default}"
bl_str_trim tag
bl_str_lower tag

# Mutated by name through list helpers.
# shellcheck disable=SC2034
declare -a values=()
# Mutated by name through list helpers.
# shellcheck disable=SC2034
declare -a unique_values=()
summary=""
count=""

bl_list_append values "$tag" "${positionals[@]}" "$tag"
bl_list_unique unique_values values
bl_list_length count unique_values
bl_str_join summary "," unique_values

if [[ "${options[verbose]-}" == "1" ]]; then
    bl_std_log_info "Cookbook parsed $count unique values."
fi

bl_std_print_message "summary=$summary"
