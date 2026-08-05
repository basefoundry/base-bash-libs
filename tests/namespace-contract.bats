#!/usr/bin/env bats

load ../lib/bash/tests/test_helper.sh

setup() {
    setup_test_tmpdir
}

@test "clean loading exports only package-prefixed framework functions" {
    run env -i PATH="$PATH" bash --noprofile --norc -c '
        source "$1/std/lib_std.sh"
        declare -a init_args=()
        base_bash_libs_init init_args --source "$1/tests/namespace-contract.bats" --
        base_bash_libs_std_import "$1/file/lib_file.sh"
        base_bash_libs_std_import "$1/git/lib_git.sh"
        base_bash_libs_std_import "$1/gh/lib_gh.sh"
        base_bash_libs_std_import "$1/str/lib_str.sh"
        base_bash_libs_std_import "$1/arg/lib_arg.sh"
        base_bash_libs_std_import "$1/list/lib_list.sh"

        for function_name in $(compgen -A function); do
            case "$function_name" in
                base_bash_libs_*|__base_bash_libs_*) ;;
                *) printf "unprefixed function: %s\n" "$function_name"; exit 1 ;;
            esac
        done

        for legacy_name in import log_info std_run str_trim list_append arg_parse update_file_section git_update_repo gh_run; do
            declare -F "$legacy_name" >/dev/null && {
                printf "legacy function exported: %s\n" "$legacy_name"
                exit 1
            }
        done

        declare -F base_bash_libs_std_log_info >/dev/null
        declare -F base_bash_libs_std_run >/dev/null
        declare -F base_bash_libs_str_trim >/dev/null
        declare -F base_bash_libs_list_append >/dev/null
        declare -F base_bash_libs_arg_parse >/dev/null
        declare -F base_bash_libs_file_update_file_section >/dev/null
        declare -F base_bash_libs_git_update_repo >/dev/null
        declare -F base_bash_libs_gh_run >/dev/null
    ' bash "$BASE_BASH_DIR"

    [ "$status" -eq 0 ]
    [[ "$output" == "" ]]
}

@test "representative application symbols survive namespaced loading" {
    run bash -c '
        import() { printf "application import\n"; }
        log_info() { printf "application log\n"; }
        std_run() { printf "application run\n"; }
        str_trim() { printf "application trim\n"; }
        COLOR_RED="application-red"

        source "$1/std/lib_std.sh"
        declare -a init_args=()
        base_bash_libs_init init_args --source "$1/tests/namespace-contract.bats" --
        base_bash_libs_std_import "$1/str/lib_str.sh"

        [[ "$(type -t import)" == function ]]
        [[ "$(type -t log_info)" == function ]]
        [[ "$(type -t std_run)" == function ]]
        [[ "$(type -t str_trim)" == function ]]
        [[ "$COLOR_RED" == application-red ]]
        [[ "$(type -t base_bash_libs_str_trim)" == function ]]
        printf "collision-safe=yes\n"
    ' bash "$BASE_BASH_DIR"

    [ "$status" -eq 0 ]
    [[ "$output" == *"collision-safe=yes"* ]]
}

@test "source files contain no legacy generic function definitions or guards" {
    run bash -c '
        for file in "$1"/*/lib_*.sh; do
            while IFS= read -r function_name; do
                case "$function_name" in
                    base_bash_libs_*|__base_bash_libs_*) ;;
                    *) printf "unprefixed function in %s: %s\n" "$file" "$function_name"; exit 1 ;;
                esac
            done < <(sed -nE "s/^([A-Za-z_][A-Za-z0-9_]*)\\(\\).*/\\1/p" "$file")
        done

        unprefixed_internal_holders="$(grep -R -n -E "^[[:space:]]*(local|declare[[:space:]]+-g)[[:space:]]+__" "$1"/*/lib_*.sh | grep -v "__base_bash_libs_" || true)"
        if [[ -n "$unprefixed_internal_holders" ]]; then
            printf '%s\\n' "$unprefixed_internal_holders"
            printf "unprefixed internal holder\\n"
            exit 1
        fi

        if grep -R -n -E "__lib_(std|file|git|gh|str|arg|list)_sourced__|__SCRIPT_(ARGS|DIR)__|__color__" "$1"/*/lib_*.sh; then
            exit 1
        fi
    ' bash "$BASE_BASH_DIR"

    [ "$status" -eq 0 ]
    [[ "$output" == "" ]]
}

@test "migration tool rewrites public, owned-state, and internal symbols" {
    local fixture="$TEST_TMPDIR/legacy-script.sh"

    printf '%s\n' \
        'import "$library_path"' \
        '__std_example__() { :; }' \
        '__str_example__() { :; }' \
        'DRY_RUN=1' > "$fixture"

    run "$BASE_REPO_ROOT/scripts/migrate-v2-symbols" "$fixture"
    [ "$status" -eq 0 ]
    grep -F 'base_bash_libs_std_import "$library_path"' "$fixture"
    grep -F '__base_bash_libs_std_example__()' "$fixture"
    grep -F '__base_bash_libs_str_example__()' "$fixture"
    grep -F 'BASE_BASH_LIBS_DRY_RUN=1' "$fixture"

    run "$BASE_REPO_ROOT/scripts/migrate-v2-symbols" --check "$fixture"
    [ "$status" -eq 0 ]
}
