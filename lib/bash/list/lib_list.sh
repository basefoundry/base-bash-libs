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

__list_assert_distinct_names__() {
    local __list_operation="${1-}" __list_result_name="${2-}" __list_source_name="${3-}"

    if [[ "$__list_result_name" == "$__list_source_name" ]]; then
        log_error -l base_bash_libs.list \
            "$__list_operation: result and source variables must be distinct; '$__list_result_name' was provided for both."
        return 1
    fi
    return 0
}

list_append() {
    if (($# < 2)); then
        fatal_error "list_append: usage: list_append <array_name> <value> [value...]"
    fi
    __std_assert_public_variable_names__ list_append "${1-}" || return 1
    local __list_array_name="$1"
    local -a __list_values=()

    assert_variable_name "$__list_array_name"
    assert_indexed_array "$__list_array_name"
    __std_assert_writable_output__ list_append "$__list_array_name" || return 1
    shift
    __list_values=("$@")
    eval "$__list_array_name+=(\"\${__list_values[@]}\")"
}

list_prepend() {
    if (($# < 2)); then
        fatal_error "list_prepend: usage: list_prepend <array_name> <value> [value...]"
    fi
    __std_assert_public_variable_names__ list_prepend "${1-}" || return 1
    local __list_array_name="$1" __list_item
    local -a __list_values=() __list_current=()

    assert_variable_name "$__list_array_name"
    assert_indexed_array "$__list_array_name"
    __std_assert_writable_output__ list_prepend "$__list_array_name" || return 1
    shift
    __list_values=("$@")
    eval "if [[ -n \"\${${__list_array_name}[@]+set}\" ]]; then __list_current=(\"\${${__list_array_name}[@]}\"); fi"
    eval "$__list_array_name=()"
    for __list_item in "${__list_values[@]+"${__list_values[@]}"}"; do
        eval "$__list_array_name+=(\"\$__list_item\")"
    done
    for __list_item in "${__list_current[@]+"${__list_current[@]}"}"; do
        eval "$__list_array_name+=(\"\$__list_item\")"
    done
}

#
# Removes every exact match from a caller-owned indexed array in place.
#
list_remove() {
    assert_arg_count "$#" 2
    __std_assert_public_variable_names__ list_remove "${1-}" || return 1
    local __list_array_name="$1" __list_needle="$2" __list_item
    local -a __list_current=() __list_filtered=()

    assert_variable_name "$__list_array_name"
    assert_indexed_array "$__list_array_name"
    __std_assert_writable_output__ list_remove "$__list_array_name" || return 1

    eval "if [[ -n \"\${${__list_array_name}[@]+set}\" ]]; then __list_current=(\"\${${__list_array_name}[@]}\"); fi"
    for __list_item in "${__list_current[@]+"${__list_current[@]}"}"; do
        [[ "$__list_item" == "$__list_needle" ]] && continue
        __list_filtered+=("$__list_item")
    done

    eval "$__list_array_name=()"
    for __list_item in "${__list_filtered[@]+"${__list_filtered[@]}"}"; do
        eval "$__list_array_name+=(\"\$__list_item\")"
    done
}

list_contains() {
    assert_arg_count "$#" 2
    __std_assert_public_variable_names__ list_contains "${2-}" || return 1
    local __list_needle="$1" __list_array_name="$2" __list_item
    local -a __list_current=()

    assert_variable_name "$__list_array_name"
    assert_indexed_array "$__list_array_name"

    eval "if [[ -n \"\${${__list_array_name}[@]+set}\" ]]; then __list_current=(\"\${${__list_array_name}[@]}\"); fi"
    for __list_item in "${__list_current[@]+"${__list_current[@]}"}"; do
        [[ "$__list_item" == "$__list_needle" ]] && return 0
    done

    return 1
}

list_unique() {
    assert_arg_count "$#" 2
    __std_assert_public_variable_names__ list_unique "${1-}" "${2-}" || return 1
    local __list_result_name="$1" __list_array_name="$2" __list_item __list_key
    local -a __list_current=() __list_unique=()
    local -A __list_seen=()

    assert_variable_name "$__list_result_name" "$__list_array_name"
    __list_assert_distinct_names__ list_unique "$__list_result_name" "$__list_array_name" || return 1
    __std_assert_writable_output__ list_unique "$__list_result_name" || return 1
    assert_indexed_array "$__list_result_name" "$__list_array_name"

    eval "if [[ -n \"\${${__list_array_name}[@]+set}\" ]]; then __list_current=(\"\${${__list_array_name}[@]}\"); fi"
    for __list_item in "${__list_current[@]+"${__list_current[@]}"}"; do
        __list_key="v:$__list_item"
        [[ -n "${__list_seen[$__list_key]+set}" ]] && continue
        __list_seen["$__list_key"]=1
        __list_unique+=("$__list_item")
    done

    eval "$__list_result_name=()"
    for __list_item in "${__list_unique[@]+"${__list_unique[@]}"}"; do
        eval "$__list_result_name+=(\"\$__list_item\")"
    done
}

list_length() {
    assert_arg_count "$#" 2
    __std_assert_public_variable_names__ list_length "${1-}" "${2-}" || return 1
    local __list_result_name="$1" __list_array_name="$2"
    local __list_count=0
    local -a __list_current=()

    assert_variable_name "$__list_result_name" "$__list_array_name"
    __list_assert_distinct_names__ list_length "$__list_result_name" "$__list_array_name" || return 1
    __std_assert_writable_output__ list_length "$__list_result_name" || return 1
    assert_indexed_array "$__list_array_name"

    eval "if [[ -n \"\${${__list_array_name}[@]+set}\" ]]; then __list_current=(\"\${${__list_array_name}[@]}\"); fi"
    # shellcheck disable=SC2199 # The + expansion safely detects Bash 4.2 empty arrays under nounset.
    if [[ -n "${__list_current[@]+set}" ]]; then
        __list_count="${#__list_current[@]}"
    fi
    printf -v "$__list_result_name" '%s' "$__list_count"
}
