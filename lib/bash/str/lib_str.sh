# shellcheck shell=bash
#
# lib_str.sh - Bash library of generic string manipulation functions.
#

[[ -n "${__lib_str_sourced__:-}" ]] && return 0
if [[ "${BASE_BASH_LIBS_STDLIB_LOADED:-}" != "1" ]]; then
    printf '%s\n' "Error: lib_str.sh requires lib_std.sh to be sourced first." >&2
    return 1 2>/dev/null || exit 1
fi
readonly __lib_str_sourced__=1

str_lower() {
    local __str_var_name="${1-}" __str_value

    assert_arg_count "$#" 1
    assert_variable_name "$__str_var_name"
    __str_value="${!__str_var_name-}"
    printf -v "$__str_var_name" '%s' "${__str_value,,}"
}

str_upper() {
    local __str_var_name="${1-}" __str_value

    assert_arg_count "$#" 1
    assert_variable_name "$__str_var_name"
    __str_value="${!__str_var_name-}"
    printf -v "$__str_var_name" '%s' "${__str_value^^}"
}

str_ltrim() {
    local __str_var_name="${1-}" __str_value

    assert_arg_count "$#" 1
    assert_variable_name "$__str_var_name"
    __str_value="${!__str_var_name-}"
    __str_value="${__str_value#"${__str_value%%[![:space:]]*}"}"
    printf -v "$__str_var_name" '%s' "$__str_value"
}

str_rtrim() {
    local __str_var_name="${1-}" __str_value

    assert_arg_count "$#" 1
    assert_variable_name "$__str_var_name"
    __str_value="${!__str_var_name-}"
    __str_value="${__str_value%"${__str_value##*[![:space:]]}"}"
    printf -v "$__str_var_name" '%s' "$__str_value"
}

str_trim() {
    assert_arg_count "$#" 1
    str_ltrim "$1"
    str_rtrim "$1"
}

str_contains() {
    local value="${1-}" needle="${2-}"

    assert_arg_count "$#" 2
    [[ "$value" == *"$needle"* ]]
}

str_starts_with() {
    local value="${1-}" prefix="${2-}"

    assert_arg_count "$#" 2
    [[ "$value" == "$prefix"* ]]
}

str_ends_with() {
    local value="${1-}" suffix="${2-}"

    assert_arg_count "$#" 2
    [[ "$value" == *"$suffix" ]]
}

# Splits a value into a caller-owned indexed array. Empty fields are preserved,
# including the final empty field produced by a trailing separator.
str_split() {
    local __str_split_result_name="${1-}" __str_split_value="${2-}" __str_split_separator="${3-}"

    assert_arg_count "$#" 3
    assert_variable_name "$__str_split_result_name"
    assert_indexed_array "$__str_split_result_name"

    local -a __str_split_fields=()
    local __str_split_remainder="$__str_split_value"

    if [[ -z "$__str_split_separator" ]]; then
        __str_split_fields=("$__str_split_value")
    else
        while [[ "$__str_split_remainder" == *"$__str_split_separator"* ]]; do
            __str_split_fields+=("${__str_split_remainder%%"$__str_split_separator"*}")
            __str_split_remainder="${__str_split_remainder#*"$__str_split_separator"}"
        done
        __str_split_fields+=("$__str_split_remainder")
    fi

    eval "$__str_split_result_name=(\"\${__str_split_fields[@]}\")"
}

str_join() {
    local result_name="${1-}" separator="${2-}" array_name="${3-}"

    assert_arg_count "$#" 3
    assert_variable_name "$result_name" "$array_name"
    assert_indexed_array "$array_name"

    local __str_join_joined="" index
    local -a __str_join_values=()
    eval "__str_join_values=(\"\${${array_name}[@]}\")"

    for index in "${!__str_join_values[@]}"; do
        if ((index == 0)); then
            __str_join_joined="${__str_join_values[$index]}"
        else
            __str_join_joined+="$separator${__str_join_values[$index]}"
        fi
    done

    printf -v "$result_name" '%s' "$__str_join_joined"
}
