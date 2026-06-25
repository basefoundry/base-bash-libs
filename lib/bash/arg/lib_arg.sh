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

__arg_declares_array_kind__() {
    local variable_name="${1-}" array_kind="${2-}" declaration

    declaration="$(declare -p "$variable_name" 2>/dev/null)" || return 1
    [[ "$declaration" == declare\ -*"$array_kind"* ]]
}

__arg_set_assoc_value__() {
    local array_name="$1" key="$2" value="$3"

    # The variable name is validated before callers reach this helper.
    # shellcheck disable=SC1087
    printf -v "$array_name[$key]" '%s' "$value"
}

__arg_parse_specs__() {
    local specs_name="$1"
    local __arg_token_kind_name="$2" __arg_token_name_name="$3"
    local -a __arg_specs=() __arg_tokens=()
    local __arg_spec __arg_remainder __arg_name __arg_kind __arg_tokens_part __arg_token
    local __arg_name_re='^[A-Za-z_][A-Za-z0-9_]*$'

    eval "__arg_specs=(\"\${${specs_name}[@]}\")"

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
            log_error "arg_parse: option spec name must be a valid Bash identifier."
            return 2
        fi
        if [[ "$__arg_kind" != "flag" && "$__arg_kind" != "value" ]]; then
            log_error "arg_parse: option spec '$__arg_name' must use kind 'flag' or 'value'."
            return 2
        fi

        IFS='|' read -r -a __arg_tokens <<<"$__arg_tokens_part"
        for __arg_token in "${__arg_tokens[@]}"; do
            if [[ -z "$__arg_token" || "$__arg_token" != -* ]]; then
                log_error "arg_parse: option spec '$__arg_name' has an invalid option token."
                return 2
            fi
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
#   - kind: "flag" or "value"
#   - token: exact option token, such as --verbose or -v
#
# Usage:
#   declare -A options=()
#   declare -a positionals=()
#   specs=("verbose|flag|--verbose|-v" "output|value|--output|-o")
#   arg_parse options positionals specs -- "$@"
#
arg_parse() {
    local options_name="${1-}" positionals_name="${2-}" specs_name="${3-}"
    local __arg_current __arg_option_token __arg_option_value __arg_option_name __arg_option_kind
    local -a __arg_positionals=()
    local -A __arg_token_kind=() __arg_token_name=()
    local __arg_parse_options=1

    if (($# < 4)) || [[ "${4-}" != "--" ]]; then
        log_error "arg_parse: usage: arg_parse <options_assoc> <positionals_array> <specs_array> -- [args...]"
        return 2
    fi

    assert_variable_name "$options_name" "$positionals_name" "$specs_name"

    if ! __arg_declares_array_kind__ "$options_name" "A"; then
        log_error "arg_parse: options variable must be an associative array declared by the caller."
        return 2
    fi
    if ! __arg_declares_array_kind__ "$positionals_name" "a"; then
        log_error "arg_parse: positionals variable must be an indexed array declared by the caller."
        return 2
    fi
    if ! __arg_declares_array_kind__ "$specs_name" "a"; then
        log_error "arg_parse: specs variable must be an indexed array declared by the caller."
        return 2
    fi

    __arg_parse_specs__ "$specs_name" __arg_token_kind __arg_token_name || return $?

    eval "$options_name=()"
    eval "$positionals_name=()"
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
            if [[ "$__arg_option_kind" != "value" ]]; then
                log_error "arg_parse: option '$__arg_option_token' does not accept a value."
                return 2
            fi

            __arg_set_assoc_value__ "$options_name" "$__arg_option_name" "$__arg_option_value"
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
                __arg_set_assoc_value__ "$options_name" "$__arg_option_name" "1"
                continue
            fi

            if (($# == 0)) || [[ "${1-}" == "--" ]]; then
                log_error "arg_parse: option '$__arg_option_token' requires a value."
                return 2
            fi
            if [[ -n "${__arg_token_kind[$1]+set}" ]]; then
                log_error "arg_parse: option '$__arg_option_token' requires a value before option '$1'."
                return 2
            fi

            __arg_option_value="$1"
            shift
            __arg_set_assoc_value__ "$options_name" "$__arg_option_name" "$__arg_option_value"
            continue
        fi

        __arg_positionals+=("$__arg_current")
    done

    eval "$positionals_name=(\"\${__arg_positionals[@]}\")"
    return 0
}
