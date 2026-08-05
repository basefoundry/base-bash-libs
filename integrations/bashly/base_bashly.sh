# shellcheck shell=bash
# Bashly adapter boundary for base-bash-libs v2.
#
# Bashly-generated code remains the CLI presentation/build layer. This adapter
# owns only the handoff to the Base Bash initialization and CLI contracts; it
# does not install Bashly, parse generated globals, or add a runtime dependency.

base_bashly_init() {
    local argv_variable="$1"
    local source_path="${BASE_BASHLY_SOURCE:-${BASH_SOURCE[1]}}"
    shift

    [[ "$argv_variable" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 2
    base_init "$argv_variable" --source "$source_path" -- "$@"
}

base_bashly_run() {
    local model="$1"
    shift

    [[ "$model" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 2
    base_cli_run "$model" -- "$@"
}

base_bashly_status() {
    local model="$1"
    shift

    [[ "$model" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 2
    base_cli_help "$model" "$@"
}
