#!/usr/bin/env bats

load ../lib/bash/tests/test_helper.sh

setup() {
    setup_test_tmpdir
    PATH="$BASE_REPO_ROOT/bin:$BASE_TEST_ORIG_PATH"
    unset DRY_RUN dry_run LOG_DEBUG LOG_UTC NO_COLOR BASE_BASH_BOOTSTRAP_SOURCE
}

create_script() {
    local script_path="$1"
    shift

    cat > "$script_path"
    chmod +x "$script_path"
}

@test "base-bash shebang preloads stdlib and calls main with filtered args" {
    local script_dir="$TEST_TMPDIR/scripts"
    local script="$script_dir/tool"

    mkdir -p "$script_dir"
    script_dir="$(cd "$script_dir" && pwd -P)"
    create_script "$script" <<'SCRIPT'
#!/usr/bin/env base-bash
# shellcheck shell=bash

import_base_bash_lib str/lib_str.sh

main() {
    local value="$1"
    str_trim value

    printf 'argc=%s\n' "$#"
    printf 'first=<%s>\n' "$1"
    printf 'second=<%s>\n' "${2-}"
    printf 'trimmed=<%s>\n' "$value"
    printf 'script-dir=%s\n' "$__SCRIPT_DIR__"
    printf 'loaded=%s\n' "${BASE_BASH_LIBS_STDLIB_LOADED:-}"
    printf 'base-home=%s\n' "${BASE_HOME-unset}"
    printf 'str-trim=%s\n' "$(type -t str_trim)"
}
SCRIPT

    bats_run "$script" --verbose-wrapper --color "  alpha  " beta

    [ "$status" -eq 0 ]
    [[ "$output" == *"argc=2"* ]]
    [[ "$output" == *"first=<  alpha  >"* ]]
    [[ "$output" == *"second=<beta>"* ]]
    [[ "$output" == *"trimmed=<alpha>"* ]]
    [[ "$output" == *"script-dir=$script_dir"* ]]
    [[ "$output" == *"loaded=1"* ]]
    [[ "$output" == *"base-home=unset"* ]]
    [[ "$output" == *"str-trim=function"* ]]
}

@test "base-bash preserves wrapper-like arguments after --" {
    local script="$TEST_TMPDIR/escape-tool"

    create_script "$script" <<'SCRIPT'
#!/usr/bin/env base-bash
# shellcheck shell=bash

main() {
    printf 'args=%s\n' "$*"
}
SCRIPT

    bats_run "$script" --color alpha -- --color omega

    [ "$status" -eq 0 ]
    [[ "$output" == *"args=alpha -- --color omega"* ]]
}

@test "base-bash reports a missing main function" {
    local script="$TEST_TMPDIR/no-main"

    create_script "$script" <<'SCRIPT'
#!/usr/bin/env base-bash
# shellcheck shell=bash

printf 'body sourced\n'
SCRIPT

    bats_run "$script"

    [ "$status" -ne 0 ]
    [[ "$output" == *"body sourced"* ]]
    [[ "$output" == *"did not define main()"* ]]
}

@test "base-bash resolves Homebrew-style libexec layout" {
    local prefix="$TEST_TMPDIR/homebrew-prefix"
    local script="$TEST_TMPDIR/brew-tool"

    mkdir -p "$prefix/bin" "$prefix/libexec"
    prefix="$(cd "$prefix" && pwd -P)"
    cp "$BASE_REPO_ROOT/bin/base-bash" "$prefix/bin/base-bash"
    chmod +x "$prefix/bin/base-bash"
    cp "$BASE_REPO_ROOT/VERSION" "$prefix/libexec/VERSION"
    cp -R "$BASE_REPO_ROOT/lib" "$prefix/libexec/lib"

    PATH="$prefix/bin:$BASE_TEST_ORIG_PATH"

    create_script "$script" <<'SCRIPT'
#!/usr/bin/env base-bash
# shellcheck shell=bash

main() {
    printf 'version=%s\n' "$BASE_BASH_LIBS_VERSION"
    printf 'lib-dir=%s\n' "$BASE_BASH_LIBS_DIR"
}
SCRIPT

    bats_run "$script"

    [ "$status" -eq 0 ]
    [[ "$output" == *"version=$(<"$BASE_REPO_ROOT/VERSION")"* ]]
    [[ "$output" == *"lib-dir=$prefix/libexec/lib/bash"* ]]
}
