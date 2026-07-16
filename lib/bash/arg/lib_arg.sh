# shellcheck shell=bash
#
# lib_arg.sh - Bash helpers for conservative option parsing.
#

[[ -n "${__lib_arg_sourced__:-}" ]] && return 0
if [[ "${BASE_BASH_LIBS_STDLIB_LOADED:-}" != "1" ]]; then
    printf '%s\n' "Error: lib_arg.sh requires lib_std.sh to be sourced first." >&2
    return 1 2>/dev/null || exit 1
fi
readonly __lib_arg_sourced__=1

__arg_set_assoc_value__() {
    local __arg_assoc_name="$1" __arg_assoc_key="$2" __arg_assoc_value="$3"

    # The variable name is validated before callers reach this helper.
    # shellcheck disable=SC1087
    printf -v "$__arg_assoc_name[$__arg_assoc_key]" '%s' "$__arg_assoc_value"
}

__arg_parse_specs__() {
    local __arg_specs_name="$1"
    local __arg_token_kind_name="$2" __arg_token_name_name="$3"
    local __arg_repeatable_names_name="${4-}"
    local -a __arg_specs=() __arg_tokens=()
    local __arg_spec __arg_remainder __arg_name __arg_kind __arg_tokens_part __arg_token
    local __arg_name_re='^[A-Za-z_][A-Za-z0-9_]*$'
    local __arg_token_re='^--?[[:alnum:]_][[:alnum:]_-]*$'
    local -A __arg_seen_names=() __arg_seen_tokens=()

    eval "__arg_specs=(\"\${${__arg_specs_name}[@]}\")"

    for __arg_spec in "${__arg_specs[@]}"; do
        __arg_name="${__arg_spec%%|*}"
        __arg_remainder="${__arg_spec#*|}"
        __arg_kind="${__arg_remainder%%|*}"
        __arg_tokens_part="${__arg_remainder#*|}"

        if [[ "$__arg_spec" == "$__arg_remainder" || "$__arg_remainder" == "$__arg_tokens_part" ||
            -z "$__arg_name" || -z "$__arg_kind" || -z "$__arg_tokens_part" ]]; then
            log_error "arg_parse: malformed option spec '$__arg_spec'."
            return 2
        fi
        if ! [[ "$__arg_name" =~ $__arg_name_re ]]; then
            log_error "arg_parse: option spec '$__arg_spec' name must be a valid Bash identifier."
            return 2
        fi
        if [[ -n "${__arg_seen_names[$__arg_name]+set}" ]]; then
            log_error "arg_parse: option spec name '$__arg_name' is duplicated."
            return 2
        fi
        __arg_seen_names["$__arg_name"]=1

        if [[ "$__arg_kind" != "flag" && "$__arg_kind" != "value" &&
            "$__arg_kind" != "repeatable" ]]; then
            log_error "arg_parse: option spec '$__arg_name' must use kind 'flag', 'value', or 'repeatable'."
            return 2
        fi

        if [[ "$__arg_kind" == "repeatable" ]]; then
            if [[ -z "$__arg_repeatable_names_name" ]]; then
                log_error "arg_parse: repeatable option spec '$__arg_name' requires an output array contract."
                return 2
            fi
            if ! __std_declares_array_kind__ "$__arg_name" "a"; then
                log_error "arg_parse: repeatable option '$__arg_name' requires a caller-declared indexed array."
                return 2
            fi
            __std_assert_writable_output__ arg_parse "$__arg_name" || return 1
            eval "$__arg_repeatable_names_name+=(\"\$__arg_name\")"
        fi

        if [[ "$__arg_tokens_part" == "|"* || "$__arg_tokens_part" == *"|" ||
            "$__arg_tokens_part" == *"||"* ]]; then
            log_error "arg_parse: option spec '$__arg_spec' contains an empty option token."
            return 2
        fi
        IFS='|' read -r -a __arg_tokens <<<"$__arg_tokens_part"
        for __arg_token in "${__arg_tokens[@]}"; do
            if ! [[ "$__arg_token" =~ $__arg_token_re ]] || [[ "$__arg_token" == *"="* ]]; then
                log_error "arg_parse: option spec '$__arg_spec' has invalid option token '$__arg_token'."
                return 2
            fi
            if [[ -n "${__arg_seen_tokens[$__arg_token]+set}" ]]; then
                log_error "arg_parse: option token '$__arg_token' is duplicated."
                return 2
            fi
            __arg_seen_tokens["$__arg_token"]=1
            __arg_set_assoc_value__ "$__arg_token_kind_name" "$__arg_token" "$__arg_kind"
            __arg_set_assoc_value__ "$__arg_token_name_name" "$__arg_token" "$__arg_name"
        done
    done

    return 0
}

#
# arg_parse - Parses simple flags and value options into caller-owned variables.
#
# Spec entries use: name|kind|token[|token...]
#   - name: valid Bash identifier used as the associative-array key
#   - kind: "flag", "value", or "repeatable"
#   - token: exact option token, such as --verbose or -v
#
# Repeatable values are published to the caller-declared indexed array whose
# name is used as the spec name, while the options result records occurrence
# with a value of "1".
#
# Usage:
#   declare -A options=()
#   declare -a positionals=()
#   specs=("verbose|flag|--verbose|-v" "output|value|--output|-o")
#   arg_parse options positionals specs -- "$@"
#
arg_parse() {
    local __arg_options_name="${1-}" __arg_positionals_name="${2-}" __arg_specs_name="${3-}"
    local __arg_current __arg_option_token __arg_option_value __arg_option_name __arg_option_kind
    local __arg_repeatable_name __arg_repeatable_index __arg_repeatable_value
    local -a __arg_positionals=() __arg_repeatable_names=() __arg_repeatable_values=()
    local -a __arg_publish_values=()
    local -A __arg_options=() __arg_token_kind=() __arg_token_name=()
    local __arg_parse_options=1

    if (($# < 4)) || [[ "${4-}" != "--" ]]; then
        log_error "arg_parse: usage: arg_parse <options_assoc> <positionals_array> <specs_array> -- [args...]"
        return 2
    fi

    assert_associative_array "$__arg_options_name"
    assert_indexed_array "$__arg_positionals_name" "$__arg_specs_name"
    __std_assert_writable_output__ arg_parse "$__arg_options_name" || return 1
    __std_assert_writable_output__ arg_parse "$__arg_positionals_name" || return 1

    __arg_parse_specs__ "$__arg_specs_name" __arg_token_kind __arg_token_name __arg_repeatable_names || return $?

    shift 4

    while (($# > 0)); do
        __arg_current="$1"
        shift

        if ((__arg_parse_options)) && [[ "$__arg_current" == "--" ]]; then
            __arg_parse_options=0
            continue
        fi

        if ((__arg_parse_options)) && [[ "$__arg_current" == --*=* ]]; then
            __arg_option_token="${__arg_current%%=*}"
            __arg_option_value="${__arg_current#*=}"
            __arg_option_kind="${__arg_token_kind[$__arg_option_token]-}"
            __arg_option_name="${__arg_token_name[$__arg_option_token]-}"

            if [[ -z "$__arg_option_kind" ]]; then
                log_error "arg_parse: unknown option '$__arg_option_token'."
                return 2
            fi
            if [[ "$__arg_option_kind" != "value" && "$__arg_option_kind" != "repeatable" ]]; then
                log_error "arg_parse: option '$__arg_option_token' does not accept a value."
                return 2
            fi

            if [[ "$__arg_option_kind" == "repeatable" ]]; then
                __arg_repeatable_values+=("$__arg_option_name" "$__arg_option_value")
                __arg_set_assoc_value__ __arg_options "$__arg_option_name" "1"
            else
                __arg_set_assoc_value__ __arg_options "$__arg_option_name" "$__arg_option_value"
            fi
            continue
        fi

        if ((__arg_parse_options)) && [[ "$__arg_current" == -* && "$__arg_current" != "-" ]]; then
            __arg_option_token="$__arg_current"
            __arg_option_kind="${__arg_token_kind[$__arg_option_token]-}"
            __arg_option_name="${__arg_token_name[$__arg_option_token]-}"

            if [[ -z "$__arg_option_kind" ]]; then
                log_error "arg_parse: unknown option '$__arg_option_token'."
                return 2
            fi

            if [[ "$__arg_option_kind" == "flag" ]]; then
                __arg_set_assoc_value__ __arg_options "$__arg_option_name" "1"
                continue
            fi

            if (($# == 0)); then
                log_error "arg_parse: option '$__arg_option_token' requires a value."
                return 2
            fi
            if [[ -n "${1-}" ]]; then
                if [[ -n "${__arg_token_kind[$1]+set}" ]]; then
                    log_error "arg_parse: option '$__arg_option_token' requires a value before option '$1'."
                    return 2
                fi
            fi

            __arg_option_value="$1"
            shift
            if [[ "$__arg_option_kind" == "repeatable" ]]; then
                __arg_repeatable_values+=("$__arg_option_name" "$__arg_option_value")
                __arg_set_assoc_value__ __arg_options "$__arg_option_name" "1"
            else
                __arg_set_assoc_value__ __arg_options "$__arg_option_name" "$__arg_option_value"
            fi
            continue
        fi

        __arg_positionals+=("$__arg_current")
    done

    eval "$__arg_options_name=()"
    for __arg_option_name in "${!__arg_options[@]}"; do
        __arg_set_assoc_value__ "$__arg_options_name" "$__arg_option_name" "${__arg_options[$__arg_option_name]}"
    done
    eval "$__arg_positionals_name=(\"\${__arg_positionals[@]}\")"

    for __arg_repeatable_name in "${__arg_repeatable_names[@]}"; do
        __arg_publish_values=()
        for ((__arg_repeatable_index = 0; __arg_repeatable_index < ${#__arg_repeatable_values[@]}; __arg_repeatable_index += 2)); do
            if [[ "${__arg_repeatable_values[__arg_repeatable_index]}" == "$__arg_repeatable_name" ]]; then
                __arg_repeatable_value="${__arg_repeatable_values[__arg_repeatable_index + 1]}"
                __arg_publish_values+=("$__arg_repeatable_value")
            fi
        done
        eval "$__arg_repeatable_name=(\"\${__arg_publish_values[@]}\")"
    done
    return 0
}
