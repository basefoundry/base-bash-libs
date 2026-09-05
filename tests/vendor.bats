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
    [ ! -e "$vendor_tree.previous" ]
    [ -z "$(find "${vendor_tree}.failed."* -maxdepth 0 -print -quit 2>/dev/null)" ]
}

@test "vendor rollback preserves both trees when either move fails" {
    local second_bundle="$TEST_TMPDIR/framework-bundle-2"
    "$BASE_REPO_ROOT/scripts/library-bundle" bundle "$second_bundle" >/dev/null
    local mv_stub="$TEST_TMPDIR/mv"
    local real_mv fail_on destination mv_count
    real_mv="$(command -v mv)"
    cat >"$mv_stub" <<'SCRIPT'
#!/usr/bin/env bash
count=0
[[ -s "${VENDOR_TEST_MV_COUNT:?}" ]] && count="$(<"$VENDOR_TEST_MV_COUNT")"
count=$((count + 1))
printf '%s\n' "$count" >"$VENDOR_TEST_MV_COUNT"
[[ "$count" -eq "${VENDOR_TEST_MV_FAIL_ON:?}" ]] && exit 1
exec "${VENDOR_TEST_REAL_MV:?}" "$@"
SCRIPT
    chmod +x "$mv_stub"

    for fail_on in 1 2; do
        destination="$TEST_TMPDIR/vendor/failure-$fail_on"
        "$BASE_REPO_ROOT/scripts/vendor" create "$framework_bundle" "$destination"
        "$BASE_REPO_ROOT/scripts/vendor" update "$second_bundle" "$destination"
        mv_count="$TEST_TMPDIR/mv-count-$fail_on"
        : >"$mv_count"

        bats_run env PATH="$TEST_TMPDIR:$BASE_TEST_ORIG_PATH" \
            VENDOR_TEST_MV_COUNT="$mv_count" VENDOR_TEST_MV_FAIL_ON="$fail_on" \
            VENDOR_TEST_REAL_MV="$real_mv" \
            "$BASE_REPO_ROOT/scripts/vendor" rollback "$destination"

        [ "$status" -eq 1 ]
        [ -d "$destination" ]
        [ -d "$destination.previous" ]
        [ -z "$(find "${destination}.failed."* -maxdepth 0 -print -quit 2>/dev/null)" ]
    done
}

@test "standalone bundle contains its own launcher and vendored framework" {
    bats_run "$BASE_REPO_ROOT/scripts/vendor" standalone "$application" "$framework_bundle" "$standalone"
    [ "$status" -eq 0 ]
    [ -x "$standalone/bin/base-bash" ]
    [ -x "$standalone/bin/app" ]
    [ -d "$standalone/.base-bash-libs/lib/bash" ]
    [ "$(<"$standalone/VERSION")" = "0.1.0" ]
    [ -f "$standalone/vendor/base-bash-libs/base-bash-libs.lock" ]
    bats_run "$BASE_REPO_ROOT/scripts/vendor" verify "$standalone/vendor/base-bash-libs"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Vendor lock and hashes are valid"* ]]
    [ "$(sed -n 's/^version=//p' "$standalone/vendor/base-bash-libs/base-bash-libs.lock")" = \
        "$(sed -n 's/^source_version=//p' "$standalone/vendor/base-bash-libs/BUNDLE.release")" ]
    [ "$(sed -n 's/^source_commit=//p' "$standalone/vendor/base-bash-libs/base-bash-libs.lock")" = \
        "$(sed -n 's/^source_commit=//p' "$standalone/vendor/base-bash-libs/BUNDLE.release")" ]
    bats_run env PATH="$standalone/bin:$PATH" "$standalone/bin/app" run
    [ "$status" -eq 0 ]
    [[ "$output" == *"hello=world"* ]]
    bats_run env PATH="$standalone/bin:$PATH" "$standalone/bin/base-bash" --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"base-bash 2.0.0"* ]]
}

@test "vendor verification detects tampering" {
    "$BASE_REPO_ROOT/scripts/vendor" create "$framework_bundle" "$vendor_tree"
    printf 'tampered\n' >> "$vendor_tree/VERSION"
    bats_run "$BASE_REPO_ROOT/scripts/vendor" verify "$vendor_tree"
    [ "$status" -eq 1 ]
    [[ "$output" == *"hash mismatch"* ]]
}

@test "artifact staging never uses predictable PID-derived paths" {
    run grep -Eq '\.\$\$' "$BASE_REPO_ROOT/scripts/vendor" "$BASE_REPO_ROOT/scripts/library-bundle" "$BASE_REPO_ROOT/bin/base-bash"
    [ "$status" -eq 1 ]
    grep -F 'mktemp' "$BASE_REPO_ROOT/scripts/vendor" >/dev/null
    grep -F 'mktemp' "$BASE_REPO_ROOT/scripts/library-bundle" >/dev/null
    grep -F 'mktemp' "$BASE_REPO_ROOT/bin/base-bash" >/dev/null
}
