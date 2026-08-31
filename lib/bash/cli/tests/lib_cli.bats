#!/usr/bin/env bats

load ../../tests/test_helper.sh

setup() {
    setup_test_tmpdir
    source "$BASE_BASH_DIR/std/lib_std.sh"
    # shellcheck disable=SC2034 # base_init receives the caller-owned argv array by name.
    declare -a setup_args=()
    base_init setup_args --source "$BASE_BASH_DIR/cli/tests/lib_cli.bats" --
    source "$BASE_BASH_DIR/cli/lib_cli.sh"
}

valid_target() {
    [[ "$1" =~ ^[a-z][a-z0-9-]*$ ]]
}

declare_demo_model() {
    base_cli_model_init demo name=demo version=2.0.0 description="Demo CLI"
    base_cli_command demo admin "Administration" aliases=manage
    base_cli_command demo admin/user "Show a user" aliases=u
    base_cli_option demo admin/user verbose flag --verbose -v help="Verbose output"
    base_cli_option demo admin/user color value --color default=blue enum=blue,green metavar=COLOR help="Output color"
    base_cli_option demo admin/user tag repeatable --tag -t help="A tag"
    base_cli_positional demo admin/user target required=true validator=valid_target help="Target name"
}

model_registry_dump() {
    local model="$1" key

    for key in "${!__base_bash_libs_cli_models[@]}"; do
        [[ "$key" == "$model|"* ]] || continue
        printf '%q=%q\n' "$key" "${__base_bash_libs_cli_models[$key]}"
    done | LC_ALL=C sort
}

assert_failed_declaration_preserves_demo() {
    local before="$1" status
    shift

    if base_cli_declare demo "$@"; then
        return 1
    else
        status=$?
    fi
    [ "$status" -eq 2 ]
    [ "$(model_registry_dump demo)" = "$before" ]
}

@test "quick declaration builds an order-independent model from table rows" {
    base_cli_declare quick <<'EOF'
# Rows are intentionally not in engine declaration order.
option|path=admin/user|name=verbose|type=flag|tokens=--verbose,-v|help=Verbose output
positional|path=admin/user|name=target|required=true|validator=valid_target
command|path=admin/user|description=Show a user|aliases=u
command|path=admin|description=Administration|aliases=manage
model|name=quick|version=2.0.0|description=Quick CLI
option|path=admin/user|name=color|type=value|tokens=--color|default=blue|enum=blue,green
EOF

    base_cli_parse quick -- manage u target-name --color green --verbose

    [ "$BASE_BASH_LIBS_CLI_RESULT_COMMAND" = "admin/user" ]
    [ "${BASE_BASH_LIBS_CLI_RESULT_OPTIONS[color]}" = "green" ]
    [ "${BASE_BASH_LIBS_CLI_RESULT_OPTIONS[verbose]}" = "1" ]
    [ "${BASE_BASH_LIBS_CLI_RESULT_POSITIONALS[0]}" = "target-name" ]
}

@test "quick declaration accepts argument rows and rejects unknown row kinds" {
    base_cli_declare args \
        'model|name=args|version=2.0.0' \
        'command|path=run|description=Run'
    base_cli_parse args -- run
    [ "$BASE_BASH_LIBS_CLI_RESULT_COMMAND" = "run" ]

    bats_run base_cli_declare broken \
        'model|name=broken' \
        'unknown|path=run'
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown row kind 'unknown'"* ]]
}

@test "quick declaration rolls back every late semantic failure" {
    base_cli_model_init demo name=original version=1.0.0 description="Original model"
    base_cli_command demo old "Original command" aliases=legacy
    base_cli_option demo old keep value --keep default=preserved
    local before
    local -a __base_bash_libs_cli_previous_positionals=(caller-owned)
    before="$(model_registry_dump demo)"

    assert_failed_declaration_preserves_demo "$before" \
        'model|name=bad/name' \
        'command|path=run|description=Run'
    assert_failed_declaration_preserves_demo "$before" \
        'model|name=replacement' \
        'command|path=missing/child|description=Missing parent'
    assert_failed_declaration_preserves_demo "$before" \
        'model|name=replacement' \
        'command|path=run|description=Run' \
        'option|path=run|name=mode|type=invalid|tokens=--mode'
    assert_failed_declaration_preserves_demo "$before" \
        'model|name=replacement' \
        'command|path=run|description=Run' \
        'positional|path=run|name=items|repeatable=true' \
        'positional|path=run|name=after'
    assert_failed_declaration_preserves_demo "$before" \
        'model|name=replacement' \
        'command|path=run|description=Run|aliases=bad/alias'
    assert_failed_declaration_preserves_demo "$before" \
        'model|name=replacement' \
        'command|path=run|description=Run' \
        'option|path=run|name=mode|type=value|tokens=--mode|enum=blue,green|default=red'
    assert_failed_declaration_preserves_demo "$before" \
        'model|name=replacement' \
        'command|path=run|description=Run' \
        'positional|path=run|name=target|required=maybe'
    assert_failed_declaration_preserves_demo "$before" \
        'model|name=replacement' \
        'command|path=run|description=Run' \
        'option|path=run|name=mode|type=value|tokens=--mode|validator=bad-name'
    [ "${__base_bash_libs_cli_previous_positionals[*]}" = caller-owned ]
}

@test "failed quick declaration leaves no partial new model" {
    if base_cli_declare unfinished \
        'model|name=unfinished' \
        'command|path=run|description=Run' \
        'option|path=run|name=mode|type=invalid|tokens=--mode'; then
        false
    else
        [ "$?" -eq 2 ]
    fi

    if __base_bash_libs_cli_model_exists__ unfinished; then
        false
    fi
    [ -z "$(model_registry_dump unfinished)" ]
}

@test "lib_cli can be sourced more than once" {
    source "$BASE_BASH_DIR/cli/lib_cli.sh"

    [ "$(type -t base_cli_model_init)" = "function" ]
}

@test "lib_cli fails clearly when sourced without stdlib" {
    bats_run bash -c 'source "$1"; rc=$?; printf "source-rc=%s\n" "$rc"; exit "$rc"' bash "$BASE_BASH_DIR/cli/lib_cli.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"lib_cli.sh requires lib_std.sh to be sourced first"* ]]
    [[ "$output" == *"source-rc=1"* ]]
}

@test "declarative model parses nested aliases and preserves result boundaries" {
    declare_demo_model

    base_cli_parse demo -- manage u target-name --color green --tag one --tag "two words" --verbose

    [ "$BASE_BASH_LIBS_CLI_RESULT_COMMAND" = "admin/user" ]
    [ "${BASE_BASH_LIBS_CLI_RESULT_OPTIONS[color]}" = "green" ]
    [ "${BASE_BASH_LIBS_CLI_RESULT_OPTIONS[verbose]}" = "1" ]
    [ "${BASE_BASH_LIBS_CLI_RESULT_REPEATABLE_COUNTS[tag]}" -eq 2 ]
    [ "${BASE_BASH_LIBS_CLI_RESULT_REPEATED[tag\|0]}" = "one" ]
    [ "${BASE_BASH_LIBS_CLI_RESULT_REPEATED[tag\|1]}" = "two words" ]

    local target color count
    base_cli_result_get_positional 0 target
    base_cli_result_get color color
    base_cli_result_count tag count
    [ "$target" = "target-name" ]
    [ "$color" = "green" ]
    [ "$count" -eq 2 ]
}

@test "help is deterministic and includes aliases, defaults, and nested usage" {
    declare_demo_model

    bats_run base_cli_help demo admin/user

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: demo admin/user [options] <target>"* ]]
    [[ "$output" == *"--color <COLOR>"* ]]
    [[ "$output" == *"(default: blue)"* ]]
    [[ "$output" == *"--tag, -t"* ]]

    bats_run base_cli_help demo
    [ "$status" -eq 0 ]
    [[ "$output" == *"admin (manage)"* ]]
}


@test "help redacts sensitive defaults and aligns long option labels" {
    base_cli_model_init secrets name=secrets version=2.0.0
    base_cli_command secrets run "Run"
    base_cli_option secrets run api_token value --api-token default='top-secret' sensitive=true help='Authentication token'
    base_cli_option secrets run extraordinarily_long_option value --extraordinarily-long-option default=visible help='Long option'

    bats_run base_cli_help secrets run

    [ "$status" -eq 0 ]
    [[ "$output" == *"--api-token <api_token>                                     Authentication token (default: <redacted>)"* ]]
    [[ "$output" != *"top-secret"* ]]
    [[ "$output" == *"--extraordinarily-long-option <extraordinarily_long_option> Long option (default: visible)"* ]]
}

@test "conflicts must reference an already declared option" {
    base_cli_model_init invalid name=invalid
    base_cli_command invalid run "Run"

    bats_run base_cli_option invalid run mode flag --mode conflicts=missing

    [ "$status" -eq 2 ]
    [[ "$output" == *"conflict option 'missing' is not declared"* ]]
}

@test "usage errors return status 2 with diagnostics" {
    declare_demo_model

    bats_run base_cli_parse demo -- admin user --color purple target-name
    [ "$status" -eq 2 ]
    [[ "$output" == *"invalid value for option 'color'"* ]]
    [[ "$output" == *"Usage: demo admin/user"* ]]

    bats_run base_cli_parse demo -- admin user target-name --unknown
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown option '--unknown'"* ]]
}

@test "double dash preserves empty and option-looking positionals" {
    base_cli_model_init dash name=dash
    base_cli_command dash run "Run"
    base_cli_positional dash run first required=true
    base_cli_positional dash run rest repeatable=true

    base_cli_parse dash -- run "" -- --looks-like-option

    [ "${#BASE_BASH_LIBS_CLI_RESULT_POSITIONALS[@]}" -eq 2 ]
    [ "${BASE_BASH_LIBS_CLI_RESULT_POSITIONALS[0]}" = "" ]
    [ "${BASE_BASH_LIBS_CLI_RESULT_POSITIONALS[1]}" = "--looks-like-option" ]
}

@test "run invokes handlers but help and version do not" {
    local handler_calls=0
    demo_handler() {
        handler_calls=$((handler_calls + 1))
    }
    base_cli_model_init runme name=runme version=2.0.0 handler=demo_handler

    base_cli_run runme -- --help
    [ "$handler_calls" -eq 0 ]
    base_cli_run runme -- --version
    [ "$handler_calls" -eq 0 ]
    base_cli_run runme --
    [ "$handler_calls" -eq 1 ]
}

@test "explicit model validation catches undeclared handlers" {
    base_cli_model_init validate name=validate handler=missing_root
    base_cli_command validate run "Run" handler=missing_run

    bats_run base_cli_validate_model validate

    [ "$status" -eq 2 ]
    [[ "$output" == *"<root>:missing_root"* ]]
    [[ "$output" == *"run:missing_run"* ]]

    missing_root() { :; }
    missing_run() { :; }
    base_cli_validate_model validate
}

@test "completion emits aliases and a self-contained completion adapter" {
    declare_demo_model

    bats_run base_cli_complete demo -- admin u
    [ "$status" -eq 0 ]
    [[ "$output" == *$'user\n'* || "$output" == user ]]
    [[ "$output" == *$'u'* ]]

    bats_run base_cli_completion_script demo _demo_complete
    [ "$status" -eq 0 ]
    [[ "$output" == *"_demo_complete()"* ]]
    [[ "$output" == *"complete -F _demo_complete demo"* ]]
}

@test "public CLI paths preserve caller variables that match internal scratch names" {
    local __base_bash_libs_cli_option_name=caller-name
    local __base_bash_libs_cli_option_path=caller-path
    local __base_bash_libs_cli_option_type=caller-type
    local -a __base_bash_libs_cli_enum_values=(caller-enum)
    local -a __base_bash_libs_cli_local_option_names=(caller-options)
    local -a __base_bash_libs_cli_local_positionals=(caller-positionals)
    local -a __base_bash_libs_cli_children=(caller-children)
    local -a __base_bash_libs_cli_option_tokens=(caller-tokens)

    declare_demo_model
    base_cli_help demo > "$TEST_TMPDIR/root-help.out"
    base_cli_help demo admin/user > "$TEST_TMPDIR/child-help.out"
    base_cli_parse demo -- admin user target-name --color green
    base_cli_complete demo -- admin user -- > "$TEST_TMPDIR/completion.out"

    [ "$__base_bash_libs_cli_option_name" = caller-name ]
    [ "$__base_bash_libs_cli_option_path" = caller-path ]
    [ "$__base_bash_libs_cli_option_type" = caller-type ]
    [ "${__base_bash_libs_cli_enum_values[*]}" = caller-enum ]
    [ "${__base_bash_libs_cli_local_option_names[*]}" = caller-options ]
    [ "${__base_bash_libs_cli_local_positionals[*]}" = caller-positionals ]
    [ "${__base_bash_libs_cli_children[*]}" = caller-children ]
    [ "${__base_bash_libs_cli_option_tokens[*]}" = caller-tokens ]
}

@test "the declarative runtime contains no eval dependency" {
    ! grep -Ev '^[[:space:]]*#' "$BASE_BASH_DIR/cli/lib_cli.sh" | grep -Eq '(^|[[:space:];])eval([[:space:];]|$)'
}
