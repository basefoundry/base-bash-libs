# shellcheck shell=bash
#
# lib_list.sh - Bash helpers for caller-owned indexed arrays.
#

[[ -n "${__lib_list_sourced__:-}" ]] && return 0
if [[ "${BASE_BASH_LIBS_STDLIB_LOADED:-}" != "1" ]]; then
    printf '%s\n' "Error: lib_list.sh requires lib_std.sh to be sourced first." >&2
    return 1 2>/dev/null || exit 1
fi
readonly __lib_list_sourced__=1

list_append() {
    local __list_array_name="${1-}"
    local -a __list_values=()

    if (($# < 2)); then
        fatal_error "list_append: usage: list_append <array_name> <value> [value...]"
    fi

    assert_variable_name "$__list_array_name"
    shift
    __list_values=("$@")
    eval "$__list_array_name+=(\"\${__list_values[@]}\")"
}

list_prepend() {
    local __list_array_name="${1-}"
    local -a __list_values=() __list_current=()

    if (($# < 2)); then
        fatal_error "list_prepend: usage: list_prepend <array_name> <value> [value...]"
    fi

    assert_variable_name "$__list_array_name"
    shift
    __list_values=("$@")
    eval "__list_current=(\"\${${__list_array_name}[@]}\")"
    eval "$__list_array_name=(\"\${__list_values[@]}\" \"\${__list_current[@]}\")"
}

list_remove() {
    local __list_array_name="${1-}" __list_needle="${2-}" __list_item
    local -a __list_current=() __list_filtered=()

    assert_arg_count "$#" 2
    assert_variable_name "$__list_array_name"

    eval "__list_current=(\"\${${__list_array_name}[@]}\")"
    for __list_item in "${__list_current[@]}"; do
        [[ "$__list_item" == "$__list_needle" ]] && continue
        __list_filtered+=("$__list_item")
    done

    eval "$__list_array_name=(\"\${__list_filtered[@]}\")"
}

list_contains() {
    local __list_needle="${1-}" __list_array_name="${2-}" __list_item
    local -a __list_current=()

    assert_arg_count "$#" 2
    assert_variable_name "$__list_array_name"

    eval "__list_current=(\"\${${__list_array_name}[@]}\")"
    for __list_item in "${__list_current[@]}"; do
        [[ "$__list_item" == "$__list_needle" ]] && return 0
    done

    return 1
}

list_unique() {
    local __list_result_name="${1-}" __list_array_name="${2-}" __list_item __list_key
    local -a __list_current=() __list_unique=()
    local -A __list_seen=()

    assert_arg_count "$#" 2
    assert_variable_name "$__list_result_name" "$__list_array_name"

    eval "__list_current=(\"\${${__list_array_name}[@]}\")"
    for __list_item in "${__list_current[@]}"; do
        __list_key="v:$__list_item"
        [[ -n "${__list_seen[$__list_key]+set}" ]] && continue
        __list_seen["$__list_key"]=1
        __list_unique+=("$__list_item")
    done

    eval "$__list_result_name=(\"\${__list_unique[@]}\")"
}

list_length() {
    local __list_result_name="${1-}" __list_array_name="${2-}"
    local -a __list_current=()

    assert_arg_count "$#" 2
    assert_variable_name "$__list_result_name" "$__list_array_name"

    eval "__list_current=(\"\${${__list_array_name}[@]}\")"
    printf -v "$__list_result_name" '%s' "${#__list_current[@]}"
}
