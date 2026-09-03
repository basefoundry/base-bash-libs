#!/usr/bin/env bats

load ../../tests/test_helper.sh

setup() {
    setup_test_tmpdir
    source "$BASE_BASH_DIR/std/lib_std.sh"
    source "$BASE_BASH_DIR/cli/lib_cli.sh"
    source "$BASE_BASH_DIR/app/lib_app.sh"
    unset APP_TEST_MODE APP_TEST_SECRET
}

validate_test_label() {
    [[ "$1" == valid ]]
}

declare_test_config() {
    base_app_init demo name=demo
    base_app_config_define demo mode enum enum=dev,prod default=dev env=APP_TEST_MODE
    base_app_config_define demo secret string required=true secret=true env=APP_TEST_SECRET
    base_app_config_define demo label string default=valid validator=validate_test_label
}

assert_demo_snapshot() {
    local value source

    base_app_config_get demo mode value
    [ "$value" = prod ]
    base_app_config_provenance demo mode source
    [ "$source" = environment ]
    base_app_config_get demo secret value
    [ "$value" = old-secret ]
    base_app_config_provenance demo secret source
    [ "$source" = environment ]
    base_app_config_get demo label value
    [ "$value" = valid ]
    base_app_config_provenance demo label source
    [ "$source" = default ]
}

@test "lib_app requires stdlib and loads cli from the package" {
    bats_run "$BASH" -c 'source "$1"' bash "$BASE_BASH_DIR/app/lib_app.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"lib_app.sh requires lib_std.sh"* ]]

    bats_run "$BASH" -c 'source "$1"; source "$2"; type -t base_cli_model_init' bash "$BASE_BASH_DIR/std/lib_std.sh" "$BASE_BASH_DIR/app/lib_app.sh"
    [ "$status" -eq 0 ]
    [ "$output" = function ]
}

@test "configuration precedence and provenance are deterministic" {
    local user_file="$TEST_TMPDIR/user.conf" project_file="$TEST_TMPDIR/project.conf" value source
    declare_test_config
    printf 'mode=dev\n' >"$user_file"
    printf 'mode=prod\n' >"$project_file"
    export APP_TEST_MODE=dev
    base_app_config_set_cli demo secret cli-secret

    base_app_config_load demo --user "$user_file" --project "$project_file" --cli mode=dev
    base_app_config_get demo mode value
    base_app_config_provenance demo mode source
    [ "$value" = dev ]
    [ "$source" = cli ]
    base_app_config_get demo secret value
    [ "$value" = cli-secret ]
}

@test "enum validation preserves a caller variable with the internal scratch name" {
    local -a __base_bash_libs_app_enum_values=(caller-owned)

    declare_test_config
    export APP_TEST_SECRET=secret
    base_app_config_load demo --cli mode=prod

    [ "${__base_bash_libs_app_enum_values[*]}" = caller-owned ]
}

@test "configuration files are data and reject malformed or unknown records" {
    local config_file="$TEST_TMPDIR/config.conf"
    declare_test_config
    printf 'mode=dev\nnot-a-record\n' >"$config_file"
    bats_run base_app_config_load demo --project "$config_file"
    [ "$status" -eq 2 ]
    [[ "$output" == *"not key=value data"* ]]

    printf 'unknown=value\n' >"$config_file"
    bats_run base_app_config_load demo --project "$config_file"
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown key 'unknown'"* ]]
    ! grep -Eq '(^|[[:space:];])eval([[:space:];]|$)' "$BASE_BASH_DIR/app/lib_app.sh"
}

@test "failed configuration loads preserve the last successful snapshot" {
    local user_file="$TEST_TMPDIR/user.conf" project_file="$TEST_TMPDIR/project.conf"
    declare_test_config
    export APP_TEST_MODE=prod APP_TEST_SECRET=old-secret
    base_app_config_load demo

    printf 'mode=dev\nnot-a-record\n' >"$user_file"
    bats_run base_app_config_load demo --user "$user_file"
    [ "$status" -eq 2 ]
    assert_demo_snapshot

    printf 'mode=dev\nunknown=value\n' >"$project_file"
    bats_run base_app_config_load demo --project "$project_file"
    [ "$status" -eq 2 ]
    assert_demo_snapshot

    export APP_TEST_MODE=staging
    bats_run base_app_config_load demo
    [ "$status" -eq 2 ]
    assert_demo_snapshot

    export APP_TEST_MODE=prod
    bats_run base_app_config_load demo --cli mode=dev --cli unknown=value
    [ "$status" -eq 2 ]
    assert_demo_snapshot

    bats_run base_app_config_load demo --cli label=invalid
    [ "$status" -eq 2 ]
    assert_demo_snapshot

    unset APP_TEST_SECRET
    bats_run base_app_config_load demo
    [ "$status" -eq 2 ]
    assert_demo_snapshot

    export APP_TEST_MODE=dev APP_TEST_SECRET=new-secret
    base_app_config_load demo --cli label=valid
    base_app_config_get demo mode value
    [ "$value" = dev ]
    base_app_config_provenance demo mode source
    [ "$source" = environment ]
    base_app_config_get demo secret value
    [ "$value" = new-secret ]
    base_app_config_provenance demo secret source
    [ "$source" = environment ]
    base_app_config_get demo label value
    [ "$value" = valid ]
    base_app_config_provenance demo label source
    [ "$source" = cli ]
}

@test "application declaration APIs accept only their documented attributes" {
    base_app_init alpha name=alpha-app description="Alpha application"
    [ "${__base_bash_libs_app_models[alpha\|name]}" = alpha-app ]
    [ "${__base_bash_libs_app_models[alpha\|description]}" = "Alpha application" ]

    base_app_config_define alpha mode string \
        env=APP_TEST_MODE default=dev required=true secret=true \
        enum=dev,prod validator=validate_test_label help="Execution mode"
    [ "${__base_bash_libs_app_config[alpha\|mode\|env]}" = APP_TEST_MODE ]
    [ "${__base_bash_libs_app_config[alpha\|mode\|default]}" = dev ]
    [ "${__base_bash_libs_app_config[alpha\|mode\|required]}" = true ]
    [ "${__base_bash_libs_app_config[alpha\|mode\|secret]}" = true ]
    [ "${__base_bash_libs_app_config[alpha\|mode\|enum]}" = dev,prod ]
    [ "${__base_bash_libs_app_config[alpha\|mode\|validator]}" = validate_test_label ]
    [ "${__base_bash_libs_app_config[alpha\|mode\|help]}" = "Execution mode" ]
}

@test "cross-context application attributes fail before model mutation" {
    base_app_init alpha name=original description="Original model"
    base_app_config_define alpha existing string default=preserved
    local before_keys="${__base_bash_libs_app_models[alpha\|config-keys]}"

    if base_app_init alpha env=IGNORED; then
        false
    else
        [ "$?" -eq 2 ]
    fi
    [ "${__base_bash_libs_app_models[alpha\|name]}" = original ]
    [ "${__base_bash_libs_app_models[alpha\|description]}" = "Original model" ]
    [ "${__base_bash_libs_app_config[alpha\|existing\|default]}" = preserved ]

    if base_app_config_define alpha ignored string name=discarded; then
        false
    else
        [ "$?" -eq 2 ]
    fi
    [ -z "${__base_bash_libs_app_config[alpha\|ignored\|type]+set}" ]
    [ "${__base_bash_libs_app_models[alpha\|config-keys]}" = "$before_keys" ]

    bats_run base_app_config_define alpha another string description=discarded
    [ "$status" -eq 2 ]
    [[ "$output" == *"attribute 'description' is not valid"* ]]
}

@test "missing required configuration and explicitly requested files fail clearly" {
    declare_test_config
    bats_run base_app_config_load demo
    [ "$status" -eq 2 ]
    [[ "$output" == *"required configuration 'secret'"* ]]

    bats_run base_app_config_load demo --project "$TEST_TMPDIR/missing.conf"
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "effective reports redact secrets and retain provenance" {
    declare_test_config
    export APP_TEST_MODE=prod APP_TEST_SECRET=top-secret
    base_app_config_load demo
    bats_run base_app_config_report demo
    [ "$status" -eq 0 ]
    [[ "$output" == *$'mode\tenvironment\tprod'* ]]
    [[ "$output" == *$'secret\tenvironment\t<redacted>'* ]]
    [[ "$output" != *"top-secret"* ]]
}

@test "effective report escapes field delimiters in non-secret values" {
    base_app_init report name=report
    base_app_config_define report message string default='unused'
    base_app_config_set_cli report message $'line\twith\nseparators'
    base_app_config_load report

    bats_run base_app_config_report report

    [ "$status" -eq 0 ]
    [[ "$output" == *$'message\tcli\tline\\twith\\nseparators'* ]]
    [ "$(printf '%s\n' "$output" | awk 'END { print NR }')" -eq 1 ]
}

@test "standard options publish opt-in policy and noninteractive prompts are denied" {
    base_cli_model_init demo name=demo
    base_cli_command demo run "Run"
    base_app_init policy
    base_app_add_standard_options demo run
    base_cli_parse demo -- run --dry-run --non-interactive --color never
    base_app_apply_standard_options policy
    [ "$BASE_BASH_LIBS_APP_DRY_RUN" -eq 1 ]
    [ "$BASE_BASH_LIBS_APP_NONINTERACTIVE" -eq 1 ]
    [ "$BASE_BASH_LIBS_APP_COLOR" = never ]
    ! base_app_should_prompt policy
}

@test "lifecycle hooks run LIFO exactly once and preserve handler status" {
    local events=()
    first_hook() { events+=("$1:$2:first"); }
    second_hook() { events+=("$1:$2:second"); }
    cleanup_hook() { events+=("$1:$2:cleanup"); }
    failing_handler() { return 7; }
    base_app_init lifecycle
    base_app_hook lifecycle fatal first first_hook
    base_app_hook lifecycle fatal second second_hook
    base_app_hook lifecycle cleanup cleanup cleanup_hook

    set +e
    base_app_run lifecycle failing_handler
    status=$?
    set -e
    [ "$status" -eq 7 ]
    [ "${events[*]}" = "fatal:7:second fatal:7:first cleanup:7:cleanup" ]
    set +e
    base_app_run lifecycle failing_handler
    status=$?
    set -e
    [ "$status" -eq 7 ]
}

@test "different-model nested runs restore outer scope and dispatch in completion order" {
    local events=() outer_status inner_status
    outer_hook() { events+=("outer:$1:$2"); }
    inner_hook() { events+=("inner:$1:$2"); }
    inner_handler() { events+=("inner:handler:$BASE_BASH_LIBS_APP_ACTIVE_MODEL"); }
    outer_handler() {
        events+=("outer:before:$BASE_BASH_LIBS_APP_ACTIVE_MODEL")
        base_app_run inner inner_handler
        base_app_status inner inner_status
        events+=("outer:after:$BASE_BASH_LIBS_APP_ACTIVE_MODEL:$BASE_BASH_LIBS_APP_LAST_STATUS:$inner_status")
    }
    base_app_init outer
    base_app_init inner
    base_app_hook outer normal normal outer_hook
    base_app_hook outer cleanup cleanup outer_hook
    base_app_hook inner normal normal inner_hook
    base_app_hook inner cleanup cleanup inner_hook

    base_app_run outer outer_handler
    base_app_status outer outer_status

    [ "${events[*]}" = "outer:before:outer inner:handler:inner inner:normal:0 inner:cleanup:0 outer:after:outer:0:0 outer:normal:0 outer:cleanup:0" ]
    [ "$outer_status" -eq 0 ]
    [ "$BASE_BASH_LIBS_APP_LAST_STATUS" -eq 0 ]
    [ -z "$BASE_BASH_LIBS_APP_ACTIVE_MODEL" ]
    [ "${#__base_bash_libs_app_run_models[@]}" -eq 0 ]
}

@test "nested failures retain each logical run status and outer lifecycle" {
    local events=() outer_status inner_status
    outer_hook() { events+=("outer:$1:$2"); }
    inner_hook() { events+=("inner:$1:$2"); }
    inner_handler() { return 7; }
    outer_handler() {
        if base_app_run inner inner_handler; then
            return 99
        else
            inner_status=$?
        fi
        events+=("outer:after:$BASE_BASH_LIBS_APP_ACTIVE_MODEL:$BASE_BASH_LIBS_APP_LAST_STATUS:$inner_status")
        return 9
    }
    base_app_init outer
    base_app_init inner
    base_app_hook outer fatal fatal outer_hook
    base_app_hook outer cleanup cleanup outer_hook
    base_app_hook inner fatal fatal inner_hook
    base_app_hook inner cleanup cleanup inner_hook

    if base_app_run outer outer_handler; then
        false
    else
        [ "$?" -eq 9 ]
    fi
    base_app_status outer outer_status
    base_app_status inner inner_status

    [ "${events[*]}" = "inner:fatal:7 inner:cleanup:7 outer:after:outer:7:7 outer:fatal:9 outer:cleanup:9" ]
    [ "$inner_status" -eq 7 ]
    [ "$outer_status" -eq 9 ]
    [ "$BASE_BASH_LIBS_APP_LAST_STATUS" -eq 9 ]
    [ -z "$BASE_BASH_LIBS_APP_ACTIVE_MODEL" ]
}

@test "same-model recursion dispatches one lifecycle per frame" {
    local events=() model_status
    same_hook() { events+=("$1:$2:$BASE_BASH_LIBS_APP_ACTIVE_MODEL"); }
    same_handler() {
        local depth="$1"
        events+=("handler:$depth:$BASE_BASH_LIBS_APP_ACTIVE_MODEL")
        if [[ "$depth" == 0 ]]; then
            base_app_run same same_handler 1
            events+=("resumed:$BASE_BASH_LIBS_APP_ACTIVE_MODEL:$BASE_BASH_LIBS_APP_LAST_STATUS")
        fi
    }
    base_app_init same
    base_app_hook same normal normal same_hook
    base_app_hook same cleanup cleanup same_hook

    base_app_run same same_handler 0
    base_app_status same model_status

    [ "${events[*]}" = "handler:0:same handler:1:same normal:0:same cleanup:0:same resumed:same:0 normal:0:same cleanup:0:same" ]
    [ "$model_status" -eq 0 ]
   [ -z "$BASE_BASH_LIBS_APP_ACTIVE_MODEL" ]
}

@test "base_app_init rejects reinitialization during an active run without losing state" {
    local events=()
    reinit_handler() {
        if base_app_init demo name=replaced; then
            events+=(same-unexpected-success)
        else
            events+=("same:$?")
        fi
        if base_app_init other name=replaced; then
            events+=(different-unexpected-success)
        else
            events+=("different:$?")
        fi
    }
    noop_handler() { :; }
    cleanup_hook() { events+=("cleanup:$2"); }

    base_app_init demo name=original
    base_app_init other name=other
    base_app_hook demo cleanup cleanup cleanup_hook

    base_app_run demo reinit_handler
    [ "${events[*]}" = "same:2 different:2 cleanup:0" ]
    [ "${__base_bash_libs_app_models[demo|name]}" = original ]
    [ "${__base_bash_libs_app_models[other|name]}" = other ]

    base_app_run demo noop_handler
    [ "${events[*]}" = "same:2 different:2 cleanup:0 cleanup:0" ]
}

@test "nested process exit and signal unwind every lifecycle frame inner first" {
    local script="$TEST_TMPDIR/nested-termination.sh"
    local events_file="$TEST_TMPDIR/events" mode expected_status expected_phase

    cat >"$script" <<'EOF'
#!/usr/bin/env bash
stdlib_path="$1"
cli_path="$2"
app_path="$3"
events_file="$4"
mode="$5"
source "$stdlib_path"
source "$cli_path"
source "$app_path"
declare -a init_args=()
base_init init_args --
outer_hook() { printf 'outer:%s:%s\n' "$1" "$2" >>"$events_file"; }
inner_hook() { printf 'inner:%s:%s\n' "$1" "$2" >>"$events_file"; }
inner_handler() {
    if [[ "$mode" == exit ]]; then
        exit 7
    fi
    kill -TERM "$$"
}
outer_handler() { base_app_run inner inner_handler; }
base_app_init outer
base_app_init inner
base_app_hook outer fatal fatal outer_hook
base_app_hook outer term term outer_hook
base_app_hook outer cleanup cleanup outer_hook
base_app_hook inner fatal fatal inner_hook
base_app_hook inner term term inner_hook
base_app_hook inner cleanup cleanup inner_hook
base_app_run outer outer_handler
EOF
    chmod +x "$script"

    for mode in exit term; do
        : >"$events_file"
        if [[ "$mode" == exit ]]; then
            expected_status=7
            expected_phase=fatal
        else
            expected_status=143
            expected_phase=term
        fi

        bats_run bash "$script" \
            "$BASE_BASH_DIR/std/lib_std.sh" \
            "$BASE_BASH_DIR/cli/lib_cli.sh" \
            "$BASE_BASH_DIR/app/lib_app.sh" \
            "$events_file" "$mode"

        [ "$status" -eq "$expected_status" ]
        [ "$(<"$events_file")" = $'inner:'"$expected_phase:$expected_status"$'\ninner:cleanup:'"$expected_status"$'\nouter:'"$expected_phase:$expected_status"$'\nouter:cleanup:'"$expected_status" ]
    done
}

@test "application status is isolated across normal failure signal and never-run models" {
    succeeds() { return 0; }
    fails() { return 7; }
    local alpha_status beta_status signal_status never_status

    base_app_init alpha
    base_app_init beta
    base_app_init signaled
    base_app_init never

    base_app_status never never_status
    [ "$never_status" -eq 0 ]

    base_app_run alpha succeeds
    base_app_status alpha alpha_status
    base_app_status beta beta_status
    [ "$alpha_status" -eq 0 ]
    [ "$beta_status" -eq 0 ]

    if base_app_run beta fails; then
        false
    else
        [ "$?" -eq 7 ]
    fi
    base_app_status alpha alpha_status
    base_app_status beta beta_status
    [ "$alpha_status" -eq 0 ]
    [ "$beta_status" -eq 7 ]
    [ "$BASE_BASH_LIBS_APP_LAST_STATUS" -eq 7 ]

    BASE_BASH_LIBS_APP_ACTIVE_MODEL=signaled
    if __base_bash_libs_app_cleanup_dispatch__ 143; then
        false
    else
        [ "$?" -eq 143 ]
    fi
    BASE_BASH_LIBS_APP_ACTIVE_MODEL=""
    base_app_status signaled signal_status
    base_app_status beta beta_status
    base_app_status never never_status
    [ "$signal_status" -eq 143 ]
    [ "$beta_status" -eq 7 ]
    [ "$never_status" -eq 0 ]
    [ "$BASE_BASH_LIBS_APP_LAST_STATUS" -eq 143 ]
}

@test "source is idempotent" {
    source "$BASE_BASH_DIR/app/lib_app.sh"
    [ "$(type -t base_app_run)" = function ]
}
