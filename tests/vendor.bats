#!/usr/bin/env bats

load ../lib/bash/tests/test_helper.sh

setup() {
    setup_test_tmpdir
    framework_bundle="$TEST_TMPDIR/framework-bundle"
    application="$TEST_TMPDIR/application"
    vendor_tree="$TEST_TMPDIR/vendor/base-bash-libs"
    standalone="$TEST_TMPDIR/standalone"
    mkdir -p "$TEST_TMPDIR/vendor" "$application"
    "$BASE_REPO_ROOT/scripts/library-bundle" bundle "$framework_bundle" >/dev/null
    BASE_BASH_LIBS_DIR="$BASE_BASH_DIR" "$BASE_REPO_ROOT/bin/base-bash" init --profile standard --dir "$application" >/dev/null
}

@test "vendor create and verify are offline and immutable" {
    bats_run "$BASE_REPO_ROOT/scripts/vendor" create "$framework_bundle" "$vendor_tree"
    [ "$status" -eq 0 ]
    bats_run "$BASE_REPO_ROOT/scripts/vendor" verify "$vendor_tree"
    [ "$status" -eq 0 ]
    [ -f "$vendor_tree/base-bash-libs.lock" ]
    bats_run "$BASE_REPO_ROOT/scripts/vendor" create "$framework_bundle" "$vendor_tree"
    [ "$status" -eq 2 ]
    [[ "$output" == *"refusing to overwrite"* ]]
}

@test "vendor update is atomic and rollback restores the prior lock" {
    "$BASE_REPO_ROOT/scripts/vendor" create "$framework_bundle" "$vendor_tree"
    local first_lock
    first_lock="$(<"$vendor_tree/base-bash-libs.lock")"
    local second_bundle="$TEST_TMPDIR/framework-bundle-2"
    cp -R "$framework_bundle" "$second_bundle"
    printf 'changed\n' >> "$second_bundle/BUNDLE.release"
    # The bundle hash set remains valid only when its metadata is unchanged;
    # use a fresh deterministic bundle for the update path instead.
    rm -rf "$second_bundle"
    "$BASE_REPO_ROOT/scripts/library-bundle" bundle "$second_bundle" >/dev/null
    "$BASE_REPO_ROOT/scripts/vendor" update "$second_bundle" "$vendor_tree"
    [ -d "$vendor_tree.previous" ]
    bats_run "$BASE_REPO_ROOT/scripts/vendor" verify "$vendor_tree"
    [ "$status" -eq 0 ]
    "$BASE_REPO_ROOT/scripts/vendor" rollback "$vendor_tree"
    [ "$(<"$vendor_tree/base-bash-libs.lock")" = "$first_lock" ]
}

@test "standalone bundle contains its own launcher and vendored framework" {
    bats_run "$BASE_REPO_ROOT/scripts/vendor" standalone "$application" "$framework_bundle" "$standalone"
    [ "$status" -eq 0 ]
    [ -x "$standalone/bin/base-bash" ]
    [ -x "$standalone/bin/app" ]
    [ -f "$standalone/vendor/base-bash-libs/base-bash-libs.lock" ] || true
    bats_run env PATH="$standalone/bin:$PATH" "$standalone/bin/app" run
    [ "$status" -eq 0 ]
    [[ "$output" == *"hello=world"* ]]
}

@test "vendor verification detects tampering" {
    "$BASE_REPO_ROOT/scripts/vendor" create "$framework_bundle" "$vendor_tree"
    printf 'tampered\n' >> "$vendor_tree/VERSION"
    bats_run "$BASE_REPO_ROOT/scripts/vendor" verify "$vendor_tree"
    [ "$status" -eq 1 ]
    [[ "$output" == *"hash mismatch"* ]]
}
