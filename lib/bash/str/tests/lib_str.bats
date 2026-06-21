#!/usr/bin/env bats

load ../../tests/test_helper.sh

setup() {
    setup_test_tmpdir
    source "$BASE_BASH_DIR/std/lib_std.sh"
    source "$BASE_BASH_DIR/str/lib_str.sh"
}

@test "lib_str can be sourced more than once" {
    source "$BASE_BASH_DIR/str/lib_str.sh"

    [ "$(type -t str_trim)" = "function" ]
}

@test "lib_str fails clearly when sourced without stdlib" {
    bats_run bash -c 'source "$1"; rc=$?; printf "source-rc=%s\n" "$rc"; exit "$rc"' bash "$BASE_BASH_DIR/str/lib_str.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"lib_str.sh requires lib_std.sh to be sourced first"* ]]
    [[ "$output" == *"source-rc=1"* ]]
    [[ "$output" != *"command not found"* ]]
}

@test "string case helpers transform text without changing other characters" {
    [ "$(str_lower "Alpha BETA 123!?")" = "alpha beta 123!?" ]
    [ "$(str_upper "Alpha beta 123!?")" = "ALPHA BETA 123!?" ]
}

@test "string trim helpers remove leading and trailing whitespace" {
    local value=$' \t  hello world  \t '

    [ "$(str_trim "$value")" = "hello world" ]
    [ "$(str_ltrim "$value")" = $'hello world  \t ' ]
    [ "$(str_rtrim "$value")" = $' \t  hello world' ]
}

@test "string predicate helpers check contains prefix and suffix" {
    str_contains "release-v1.2.3.tar.gz" "v1.2"
    str_starts_with "release-v1.2.3.tar.gz" "release-"
    str_ends_with "release-v1.2.3.tar.gz" ".tar.gz"

    if str_contains "release-v1.2.3.tar.gz" "v2"; then
        return 1
    fi
    if str_starts_with "release-v1.2.3.tar.gz" "debug-"; then
        return 1
    fi
    if str_ends_with "release-v1.2.3.tar.gz" ".zip"; then
        return 1
    fi
}

@test "str_split stores delimited fields in a named array" {
    local -a parts=()

    str_split parts "alpha,beta,,gamma" ","

    [ "${#parts[@]}" -eq 4 ]
    [ "${parts[0]}" = "alpha" ]
    [ "${parts[1]}" = "beta" ]
    [ "${parts[2]}" = "" ]
    [ "${parts[3]}" = "gamma" ]
}

@test "str_split rejects invalid result variable names" {
    local stderr_file="$TEST_TMPDIR/str-split.err"
    local rc

    if str_split "not-valid" "alpha,beta" "," 2>"$stderr_file"; then
        rc=0
    else
        rc=$?
    fi

    [ "$rc" -eq 1 ]
    [[ "$(cat "$stderr_file")" == *"str_split: result variable name must be a valid Bash variable name."* ]]
}

@test "str_join writes joined array values to a named result variable" {
    local -a values=("alpha" "beta gamma" "")
    local joined=""

    str_join joined "|" values

    [ "$joined" = "alpha|beta gamma|" ]
}

@test "str_join rejects invalid variable names" {
    local -a values=("alpha")
    local stderr_file="$TEST_TMPDIR/str-join.err"
    local rc

    if str_join joined " " "not-valid" 2>"$stderr_file"; then
        rc=0
    else
        rc=$?
    fi

    [ "$rc" -eq 1 ]
    [[ "$(cat "$stderr_file")" == *"str_join: array variable name must be a valid Bash variable name."* ]]

    if str_join "not-valid" " " values 2>"$stderr_file"; then
        rc=0
    else
        rc=$?
    fi

    [ "$rc" -eq 1 ]
    [[ "$(cat "$stderr_file")" == *"str_join: result variable name must be a valid Bash variable name."* ]]
}

@test "str_in_array checks membership in a named array" {
    local -a values=("alpha" "beta gamma" "")

    str_in_array "alpha" values
    str_in_array "beta gamma" values
    str_in_array "" values

    if str_in_array "delta" values; then
        return 1
    fi
}

@test "str_in_array rejects invalid array variable names" {
    local stderr_file="$TEST_TMPDIR/str-in-array.err"
    local rc

    if str_in_array "alpha" "not-valid" 2>"$stderr_file"; then
        rc=0
    else
        rc=$?
    fi

    [ "$rc" -eq 1 ]
    [[ "$(cat "$stderr_file")" == *"str_in_array: array variable name must be a valid Bash variable name."* ]]
}
