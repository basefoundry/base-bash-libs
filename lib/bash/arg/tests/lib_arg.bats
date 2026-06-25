#!/usr/bin/env bats

load ../../tests/test_helper.sh

setup() {
    setup_test_tmpdir
    source "$BASE_BASH_DIR/std/lib_std.sh"
    source "$BASE_BASH_DIR/arg/lib_arg.sh"
}

create_script() {
    local script_path="$1"
    cat > "$script_path"
    chmod +x "$script_path"
}

@test "lib_arg can be sourced more than once" {
    source "$BASE_BASH_DIR/arg/lib_arg.sh"

    [ "$(type -t arg_parse)" = "function" ]
}

@test "lib_arg fails clearly when sourced without stdlib" {
    bats_run bash -c 'source "$1"; rc=$?; printf "source-rc=%s\n" "$rc"; exit "$rc"' bash "$BASE_BASH_DIR/arg/lib_arg.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"lib_arg.sh requires lib_std.sh to be sourced first"* ]]
    [[ "$output" == *"source-rc=1"* ]]
    [[ "$output" != *"command not found"* ]]
}

@test "lib_arg requires the stdlib loaded marker" {
    bats_run bash -c 'log_error() { :; }; log_debug() { :; }; source "$1"; rc=$?; printf "source-rc=%s\n" "$rc"; exit "$rc"' bash "$BASE_BASH_DIR/arg/lib_arg.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"lib_arg.sh requires lib_std.sh to be sourced first"* ]]
    [[ "$output" == *"source-rc=1"* ]]
}

@test "arg_parse stores flags values and positionals" {
    local -a specs=(
        "verbose|flag|--verbose|-v"
        "output|value|--output|-o"
    )
    local -A options=()
    local -a positionals=()

    arg_parse options positionals specs -- --verbose -o "build result.txt" alpha -- beta gamma

    [ "${options[verbose]}" = "1" ]
    [ "${options[output]}" = "build result.txt" ]
    [ "${#positionals[@]}" -eq 3 ]
    [ "${positionals[0]}" = "alpha" ]
    [ "${positionals[1]}" = "beta" ]
    [ "${positionals[2]}" = "gamma" ]
}

@test "arg_parse accepts long option equals values and repeated options" {
    local -a specs=(
        "verbose|flag|--verbose|-v"
        "output|value|--output|-o"
    )
    local -A options=()
    local -a positionals=()

    arg_parse options positionals specs -- --output=first.txt --output second.txt -v -v item

    [ "${options[verbose]}" = "1" ]
    [ "${options[output]}" = "second.txt" ]
    [ "${#positionals[@]}" -eq 1 ]
    [ "${positionals[0]}" = "item" ]
}

@test "arg_parse returns usage status for unknown options" {
    local -a specs=("verbose|flag|--verbose|-v")
    local -A options=()
    local -a positionals=()
    local parse_status=0

    arg_parse options positionals specs -- --unknown || parse_status=$?

    [ "$parse_status" -eq 2 ]
}

@test "arg_parse returns usage status when option values are missing" {
    local -a specs=("output|value|--output|-o")
    local -A options=()
    local -a positionals=()
    local parse_status=0

    arg_parse options positionals specs -- --output || parse_status=$?

    [ "$parse_status" -eq 2 ]
}

@test "arg_parse rejects registered options as missing option values" {
    local -a specs=(
        "verbose|flag|--verbose|-v"
        "output|value|--output|-o"
    )
    local -A options=()
    local -a positionals=()
    local parse_status=0

    arg_parse options positionals specs -- --output --verbose || parse_status=$?

    [ "$parse_status" -eq 2 ]
    [ -z "${options[output]+set}" ]
    [ -z "${options[verbose]+set}" ]
}

@test "arg_parse rejects invalid variable names without echoing values" {
    local script="$TEST_TMPDIR/arg-invalid-vars.sh"

    create_script "$script" <<EOF
#!/usr/bin/env bash
source "$BASE_BASH_DIR/std/lib_std.sh"
source "$BASE_BASH_DIR/arg/lib_arg.sh"
secret="not-valid"
declare -a specs=("verbose|flag|--verbose")
arg_parse "\$secret" positionals specs -- --verbose
EOF

    bats_run bash "$script"

    [ "$status" -eq 1 ]
    [[ "$output" == *"assert_variable_name expects valid Bash variable names"* ]]
    [[ "$output" != *"not-valid"* ]]
}

@test "arg_parse rejects malformed specs" {
    local -a specs=("verbose|maybe|--verbose")
    local -A options=()
    local -a positionals=()
    local parse_status=0

    arg_parse options positionals specs -- --verbose || parse_status=$?

    [ "$parse_status" -eq 2 ]
}
