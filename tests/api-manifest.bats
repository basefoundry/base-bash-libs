#!/usr/bin/env bats

load ../lib/bash/tests/test_helper.sh

setup() {
    setup_test_tmpdir
}

@test "canonical API manifest validates and exposes the complete module graph" {
    run "$BASE_REPO_ROOT/scripts/api-manifest" check
    [ "$status" -eq 0 ]
    [[ "$output" == *"API manifest is valid."* ]]

    run "$BASE_REPO_ROOT/scripts/api-manifest" module-paths
    [ "$status" -eq 0 ]
    [[ "$output" == *$'sourceable-library\tlib/bash/std/README.md\tlib/bash/std/tests/lib_std.bats'* ]]
    [[ "$output" == *$'executable-launcher\tdocs/v2-api-contract.md\ttests/launcher.bats'* ]]
}

@test "manifest symbols match source declarations and generated reference" {
    manifest_symbols="$TEST_TMPDIR/manifest-symbols"
    source_symbols="$TEST_TMPDIR/source-symbols"

    "$BASE_REPO_ROOT/scripts/api-manifest" symbols | sort -u > "$manifest_symbols"
    rg -No '^base_[A-Za-z0-9_]+\(\)' \
        "$BASE_REPO_ROOT/lib/bash" "$BASE_REPO_ROOT/bin/base-bash" |
        sed -E 's#^.*:([a-zA-Z0-9_]+)\(.*#\1#' | sort -u > "$source_symbols"

    run diff -u "$source_symbols" "$manifest_symbols"
    [ "$status" -eq 0 ]
    grep -F '`base_std_run`' "$BASE_REPO_ROOT/docs/api-reference.md"
    grep -F '`base_launcher_run_script`' "$BASE_REPO_ROOT/docs/api-reference.md"
}

@test "manifest rejects an invalid namespace and a dependency cycle" {
    invalid_namespace="$TEST_TMPDIR/invalid-namespace.yaml"
    cycle_manifest="$TEST_TMPDIR/cycle.yaml"

    sed 's/public_function_prefix: base_/public_function_prefix: bl_/' \
        "$BASE_REPO_ROOT/base_api_manifest.yaml" > "$invalid_namespace"
    run "$BASE_REPO_ROOT/scripts/api-manifest" check "$invalid_namespace"
    [ "$status" -ne 0 ]
    [[ "$output" == *"public_function_prefix must be base_"* ]]

    perl -0pe 's/dependencies: none/dependencies: file/' \
        "$BASE_REPO_ROOT/base_api_manifest.yaml" > "$cycle_manifest"
    run "$BASE_REPO_ROOT/scripts/api-manifest" check "$cycle_manifest"
    [ "$status" -ne 0 ]
    [[ "$output" == *"dependency cycle"* ]]
}
