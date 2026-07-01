#!/usr/bin/env bats

load ../../tests/test_helper.sh

setup() {
    setup_test_tmpdir
    source "$BASE_BASH_DIR/std/lib_std.sh"
    source "$BASE_BASH_DIR/str/lib_str.sh"
}

create_script() {
    local script_path="$1"
    cat > "$script_path"
    chmod +x "$script_path"
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

@test "lib_str requires the stdlib loaded marker" {
    bats_run bash -c 'log_error() { :; }; log_debug() { :; }; source "$1"; rc=$?; printf "source-rc=%s\n" "$rc"; exit "$rc"' bash "$BASE_BASH_DIR/str/lib_str.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"lib_str.sh requires lib_std.sh to be sourced first"* ]]
    [[ "$output" == *"source-rc=1"* ]]
}

@test "string case helpers transform text without changing other characters" {
    local value="Alpha BETA 123!?"
    local stdout_file="$TEST_TMPDIR/case.stdout"

    str_lower value >"$stdout_file"

    [ "$value" = "alpha beta 123!?" ]
    [ ! -s "$stdout_file" ]

    str_upper value >"$stdout_file"

    [ "$value" = "ALPHA BETA 123!?" ]
    [ ! -s "$stdout_file" ]
}

@test "string trim helpers remove leading and trailing whitespace" {
    local value=$' \t  hello world  \t '
    local left=$' \t  hello world  \t '
    local right=$' \t  hello world  \t '
    local stdout_file="$TEST_TMPDIR/trim.stdout"

    str_trim value >"$stdout_file"
    str_ltrim left >"$stdout_file"
    str_rtrim right >"$stdout_file"

    [ "$value" = "hello world" ]
    [ "$left" = $'hello world  \t ' ]
    [ "$right" = $' \t  hello world' ]
    [ ! -s "$stdout_file" ]
}

@test "string transform helpers reject invalid variable names" {
    local script="$TEST_TMPDIR/string-transform-invalid.sh"

    create_script "$script" <<EOF
#!/usr/bin/env bash
source "$BASE_BASH_DIR/std/lib_std.sh"
source "$BASE_BASH_DIR/str/lib_str.sh"
secret="not-valid"
str_trim "\$secret"
EOF

    bats_run bash "$script"

    [ "$status" -eq 1 ]
    [[ "$output" == *"assert_variable_name expects valid Bash variable names"* ]]
    [[ "$output" != *"not-valid"* ]]
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

@test "string predicate helpers reject incorrect argument counts" {
    local script="$TEST_TMPDIR/string-predicate-arity.sh"

    create_script "$script" <<EOF
#!/usr/bin/env bash
source "$BASE_BASH_DIR/std/lib_std.sh"
source "$BASE_BASH_DIR/str/lib_str.sh"
"\$@"
EOF

    bats_run bash "$script" str_contains "needle-only"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Argument count mismatch: expected 2 but got 1 arguments"* ]]

    bats_run bash "$script" str_starts_with "value" "prefix" "extra"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Argument count mismatch: expected 2 but got 3 arguments"* ]]

    bats_run bash "$script" str_ends_with
    [ "$status" -eq 1 ]
    [[ "$output" == *"Argument count mismatch: expected 2 but got 0 arguments"* ]]
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

@test "str_split can store results in an array named fields" {
    local -a fields=()

    str_split fields "alpha:beta:gamma" ":"

    [ "${#fields[@]}" -eq 3 ]
    [ "${fields[0]}" = "alpha" ]
    [ "${fields[1]}" = "beta" ]
    [ "${fields[2]}" = "gamma" ]
}

@test "str_split rejects invalid result variable names" {
    local script="$TEST_TMPDIR/str-split-invalid.sh"

    create_script "$script" <<EOF
#!/usr/bin/env bash
source "$BASE_BASH_DIR/std/lib_std.sh"
source "$BASE_BASH_DIR/str/lib_str.sh"
secret="not-valid"
str_split "\$secret" "alpha,beta" ","
EOF

    bats_run bash "$script"

    [ "$status" -eq 1 ]
    [[ "$output" == *"assert_variable_name expects valid Bash variable names"* ]]
    [[ "$output" != *"not-valid"* ]]
}

@test "str_join writes joined array values to a named result variable" {
    local -a values=("alpha" "beta gamma" "")
    local joined=""

    str_join joined "|" values

    [ "$joined" = "alpha|beta gamma|" ]
}

@test "str_join rejects invalid variable names" {
    local script="$TEST_TMPDIR/str-join-invalid-array.sh"

    create_script "$script" <<EOF
#!/usr/bin/env bash
source "$BASE_BASH_DIR/std/lib_std.sh"
source "$BASE_BASH_DIR/str/lib_str.sh"
secret="not-valid"
str_join joined " " "\$secret"
EOF

    bats_run bash "$script"

    [ "$status" -eq 1 ]
    [[ "$output" == *"assert_variable_name expects valid Bash variable names"* ]]
    [[ "$output" != *"not-valid"* ]]

    script="$TEST_TMPDIR/str-join-invalid-result.sh"
    create_script "$script" <<EOF
#!/usr/bin/env bash
source "$BASE_BASH_DIR/std/lib_std.sh"
source "$BASE_BASH_DIR/str/lib_str.sh"
declare -a values=("alpha")
secret="not-valid"
str_join "\$secret" " " values
EOF

    bats_run bash "$script"

    [ "$status" -eq 1 ]
    [[ "$output" == *"assert_variable_name expects valid Bash variable names"* ]]
    [[ "$output" != *"not-valid"* ]]
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
    local script="$TEST_TMPDIR/str-in-array-invalid.sh"

    create_script "$script" <<EOF
#!/usr/bin/env bash
source "$BASE_BASH_DIR/std/lib_std.sh"
source "$BASE_BASH_DIR/str/lib_str.sh"
secret="not-valid"
str_in_array "alpha" "\$secret"
EOF

    bats_run bash "$script"

    [ "$status" -eq 1 ]
    [[ "$output" == *"assert_variable_name expects valid Bash variable names"* ]]
    [[ "$output" != *"not-valid"* ]]
}

@test "string array helpers reject non-indexed arrays" {
    local script="$TEST_TMPDIR/str-non-indexed.sh"

    create_script "$script" <<EOF
#!/usr/bin/env bash
source "$BASE_BASH_DIR/std/lib_std.sh"
source "$BASE_BASH_DIR/str/lib_str.sh"
parts=""
str_split parts "alpha,beta" ","
EOF

    bats_run bash "$script"

    [ "$status" -eq 1 ]
    [[ "$output" == *"must be an indexed array declared by the caller"* ]]

    create_script "$script" <<EOF
#!/usr/bin/env bash
source "$BASE_BASH_DIR/std/lib_std.sh"
source "$BASE_BASH_DIR/str/lib_str.sh"
declare -A values=([alpha]="one")
joined=""
str_join joined "," values
EOF

    bats_run bash "$script"

    [ "$status" -eq 1 ]
    [[ "$output" == *"must be an indexed array declared by the caller"* ]]

    create_script "$script" <<EOF
#!/usr/bin/env bash
source "$BASE_BASH_DIR/std/lib_std.sh"
source "$BASE_BASH_DIR/str/lib_str.sh"
values="alpha"
str_in_array "alpha" values
EOF

    bats_run bash "$script"

    [ "$status" -eq 1 ]
    [[ "$output" == *"must be an indexed array declared by the caller"* ]]
}
