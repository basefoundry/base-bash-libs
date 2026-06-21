# shellcheck shell=bash
#
# lib_str.sh - Bash library of generic string manipulation functions.
#

[[ -n "${__lib_str_sourced__:-}" ]] && return 0
if ! declare -F log_error >/dev/null || ! declare -F log_debug >/dev/null; then
    printf '%s\n' "Error: lib_str.sh requires lib_std.sh to be sourced first." >&2
    return 1 2>/dev/null || exit 1
fi
readonly __lib_str_sourced__=1

str_lower() {
    local value="${1-}"
    printf '%s' "${value,,}"
}

str_upper() {
    local value="${1-}"
    printf '%s' "${value^^}"
}

str_ltrim() {
    local value="${1-}"
    value="${value#"${value%%[![:space:]]*}"}"
    printf '%s' "$value"
}

str_rtrim() {
    local value="${1-}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

str_trim() {
    local value="${1-}"
    value="$(str_ltrim "$value")"
    str_rtrim "$value"
}

str_contains() {
    local value="${1-}" needle="${2-}"
    [[ "$value" == *"$needle"* ]]
}

str_starts_with() {
    local value="${1-}" prefix="${2-}"
    [[ "$value" == "$prefix"* ]]
}

str_ends_with() {
    local value="${1-}" suffix="${2-}"
    [[ "$value" == *"$suffix" ]]
}

str_split() {
    local result_name="${1-}" value="${2-}" separator="${3-}"

    if ! __is_valid_variable_name__ "$result_name"; then
        log_error "str_split: result variable name must be a valid Bash variable name."
        return 1
    fi

    local -a fields=()
    local remainder="$value"

    if [[ -z "$separator" ]]; then
        fields=("$value")
    else
        while [[ "$remainder" == *"$separator"* ]]; do
            fields+=("${remainder%%"$separator"*}")
            remainder="${remainder#*"$separator"}"
        done
        fields+=("$remainder")
    fi

    eval "$result_name=(\"\${fields[@]}\")"
}

str_join() {
    local result_name="${1-}" separator="${2-}" array_name="${3-}"

    if ! __is_valid_variable_name__ "$array_name"; then
        log_error "str_join: array variable name must be a valid Bash variable name."
        return 1
    fi
    if ! __is_valid_variable_name__ "$result_name"; then
        log_error "str_join: result variable name must be a valid Bash variable name."
        return 1
    fi

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

str_in_array() {
    local needle="${1-}" array_name="${2-}" item

    if ! __is_valid_variable_name__ "$array_name"; then
        log_error "str_in_array: array variable name must be a valid Bash variable name."
        return 1
    fi

    local -a __str_in_array_values=()
    eval "__str_in_array_values=(\"\${${array_name}[@]}\")"

    for item in "${__str_in_array_values[@]}"; do
        [[ "$item" == "$needle" ]] && return 0
    done

    return 1
}
