#!/usr/bin/env bats

load ../../tests/test_helper.sh

setup() {
    setup_test_tmpdir
    source "$BASE_BASH_DIR/std/lib_std.sh"
    source "$BASE_BASH_DIR/list/lib_list.sh"
}

create_script() {
    local script_path="$1"
    cat > "$script_path"
    chmod +x "$script_path"
}

@test "lib_list can be sourced more than once" {
    source "$BASE_BASH_DIR/list/lib_list.sh"

    [ "$(type -t list_append)" = "function" ]
}

@test "lib_list fails clearly when sourced without stdlib" {
    bats_run bash -c 'source "$1"; rc=$?; printf "source-rc=%s\n" "$rc"; exit "$rc"' bash "$BASE_BASH_DIR/list/lib_list.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"lib_list.sh requires lib_std.sh to be sourced first"* ]]
    [[ "$output" == *"source-rc=1"* ]]
    [[ "$output" != *"command not found"* ]]
}

@test "lib_list requires the stdlib loaded marker" {
    bats_run bash -c 'log_error() { :; }; log_debug() { :; }; source "$1"; rc=$?; printf "source-rc=%s\n" "$rc"; exit "$rc"' bash "$BASE_BASH_DIR/list/lib_list.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"lib_list.sh requires lib_std.sh to be sourced first"* ]]
    [[ "$output" == *"source-rc=1"* ]]
}

@test "list_append and list_prepend mutate caller arrays in place" {
    local -a values=("middle")

    list_append values "tail one" ""
    list_prepend values "head"

    [ "${#values[@]}" -eq 4 ]
    [ "${values[0]}" = "head" ]
    [ "${values[1]}" = "middle" ]
    [ "${values[2]}" = "tail one" ]
    [ "${values[3]}" = "" ]
}

@test "list_remove deletes matching values and preserves order" {
    local -a values=("alpha" "beta" "alpha" "" "gamma")

    list_remove values "alpha"
    list_remove values ""

    [ "${#values[@]}" -eq 2 ]
    [ "${values[0]}" = "beta" ]
    [ "${values[1]}" = "gamma" ]
}

@test "list_contains checks membership without printing" {
    local -a values=("alpha" "beta gamma" "")
    local stdout_file="$TEST_TMPDIR/list-contains.out"

    list_contains "beta gamma" values >"$stdout_file"
    list_contains "" values >>"$stdout_file"

    if list_contains "delta" values; then
        return 1
    fi
    [ ! -s "$stdout_file" ]
}

@test "list_unique stores deduplicated values in a named result array" {
    local -a values=("alpha" "beta" "alpha" "" "beta" "")
    local -a unique=()

    list_unique unique values

    [ "${#unique[@]}" -eq 3 ]
    [ "${unique[0]}" = "alpha" ]
    [ "${unique[1]}" = "beta" ]
    [ "${unique[2]}" = "" ]
}

@test "list_length stores the array length in a named variable" {
    local -a values=("alpha" "beta gamma" "")
    local count=""

    list_length count values

    [ "$count" = "3" ]
}

@test "list helpers reject invalid variable names without echoing values" {
    local script="$TEST_TMPDIR/list-invalid-vars.sh"

    create_script "$script" <<EOF
#!/usr/bin/env bash
source "$BASE_BASH_DIR/std/lib_std.sh"
source "$BASE_BASH_DIR/list/lib_list.sh"
secret="not-valid"
list_append "\$secret" "value"
EOF

    bats_run bash "$script"

    [ "$status" -eq 1 ]
    [[ "$output" == *"assert_variable_name expects valid Bash variable names"* ]]
    [[ "$output" != *"not-valid"* ]]
}
