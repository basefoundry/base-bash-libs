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

vendor_test_make_copy_race_stub() {
    local stub_dir="$TEST_TMPDIR/racing-cp-bin"
    mkdir -p "$stub_dir"
    cat > "$stub_dir/cp" <<'EOF'
#!/usr/bin/env bash
set -u
source_path="${@: -2:1}"
if [[ "$source_path" == "${VENDOR_TEST_RACE_SOURCE-}" ]]; then
    if [[ "${VENDOR_TEST_RACE_MODE-}" == parent ]]; then
        mv -- "$VENDOR_TEST_RACE_PARENT" "$VENDOR_TEST_RACE_BACKUP" || exit 1
        ln -s -- "$VENDOR_TEST_RACE_TARGET" "$VENDOR_TEST_RACE_PARENT" || {
            mv -- "$VENDOR_TEST_RACE_BACKUP" "$VENDOR_TEST_RACE_PARENT"
            exit 1
        }
        "$VENDOR_TEST_REAL_CP" "$@"
        copy_status=$?
        rm -f -- "$VENDOR_TEST_RACE_PARENT"
        mv -- "$VENDOR_TEST_RACE_BACKUP" "$VENDOR_TEST_RACE_PARENT" || exit 1
        exit "$copy_status"
    fi
    mv -- "$VENDOR_TEST_RACE_SOURCE" "$VENDOR_TEST_RACE_BACKUP" || exit 1
    ln -s -- "$VENDOR_TEST_RACE_TARGET" "$VENDOR_TEST_RACE_SOURCE" || {
        mv -- "$VENDOR_TEST_RACE_BACKUP" "$VENDOR_TEST_RACE_SOURCE"
        exit 1
    }
    "$VENDOR_TEST_REAL_CP" "$@"
    copy_status=$?
    rm -f -- "$VENDOR_TEST_RACE_SOURCE"
    mv -- "$VENDOR_TEST_RACE_BACKUP" "$VENDOR_TEST_RACE_SOURCE" || exit 1
    exit "$copy_status"
fi
exec "$VENDOR_TEST_REAL_CP" "$@"
EOF
    chmod +x "$stub_dir/cp"
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
    local stdout_file="$TEST_TMPDIR/standalone.stdout" stderr_file="$TEST_TMPDIR/standalone.stderr"

    mkdir -p "$application/assets" "$application/.git" "$application/dist/prior"
    printf 'local-secret-marker\n' > "$application/.env"
    printf 'repository-marker\n' > "$application/.git/config"
    printf 'old-output-marker\n' > "$application/dist/prior/marker"
    printf 'runtime asset\n' > "$application/assets/runtime.txt"

    bats_run "$BASE_REPO_ROOT/scripts/vendor" standalone "$application" "$framework_bundle" "$standalone" \
        --include assets/runtime.txt
    [ "$status" -eq 0 ]
    [ -x "$standalone/bin/base-bash" ]
    [ -x "$standalone/bin/app" ]
    [ -d "$standalone/lib/bash" ]
    [ -f "$standalone/config/app.conf.example" ]
    [ "$(<"$standalone/assets/runtime.txt")" = 'runtime asset' ]
    [ ! -e "$standalone/.env" ]
    [ ! -e "$standalone/.git" ]
    [ ! -e "$standalone/dist" ]
    [ ! -e "$standalone/Makefile" ]
    [ ! -e "$standalone/tests/app.bats" ]
    [ ! -e "$standalone/.github" ]
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
    if env NO_COLOR=1 PATH="$standalone/bin:$PATH" "$standalone/bin/app" \
        run --color always --verbose >"$stdout_file" 2>"$stderr_file"; then
        status=0
    else
        status=$?
    fi
    [ "$status" -eq 0 ]
    [[ "$(<"$stdout_file")" == *"hello=world"* ]]
    [[ "$(<"$stderr_file")" == *$'\033['* ]]
    local expected_version
    expected_version="$(<"$BASE_REPO_ROOT/VERSION")"
    bats_run env PATH="$standalone/bin:$PATH" "$standalone/bin/base-bash" --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"base-bash $expected_version"* ]]
}

@test "standalone rejects destinations inside source and unsafe optional payload entries" {
    mkdir -p "$application/dist" "$application/assets"
    printf 'outside\n' > "$TEST_TMPDIR/outside-marker"
    ln -s "$TEST_TMPDIR/outside-marker" "$application/assets/linked-marker"

    bats_run "$BASE_REPO_ROOT/scripts/vendor" standalone "$application" "$framework_bundle" \
        "$application/dist/standalone"
    [ "$status" -eq 2 ]
    [[ "$output" == *"destination must be outside the application source tree"* ]]
    [ ! -e "$application/dist/standalone" ]

    bats_run "$BASE_REPO_ROOT/scripts/vendor" standalone "$application" "$framework_bundle" \
        "$TEST_TMPDIR/standalone-symlink" --include assets/linked-marker
    [ "$status" -eq 2 ]
    [[ "$output" == *"traverses a symlink"* ]]
    [ ! -e "$TEST_TMPDIR/standalone-symlink" ]

    bats_run "$BASE_REPO_ROOT/scripts/vendor" standalone "$application" "$framework_bundle" \
        "$TEST_TMPDIR/standalone-unlisted" --include tests/app.bats
    [ "$status" -eq 2 ]
    [[ "$output" == *"must be explicitly selected under assets/ or config/"* ]]
    [ ! -e "$TEST_TMPDIR/standalone-unlisted" ]
}

@test "standalone destination containment uses filesystem identity on case-insensitive volumes" {
    local alternate_application="${application^^}"
    mkdir -p "$application/dist"
    [[ "$application" -ef "$alternate_application" ]] || skip "The test volume is case-sensitive."

    bats_run "$BASE_REPO_ROOT/scripts/vendor" standalone "$application" "$framework_bundle" \
        "$alternate_application/dist/case-aliased-output"
    [ "$status" -eq 2 ]
    [[ "$output" == *"destination must be outside the application source tree"* ]]
    [ ! -e "$application/dist/case-aliased-output" ]
}

@test "standalone refuses leaf and parent symlink swaps during payload copy" {
    local real_cp canonical_application destination="$TEST_TMPDIR/race-leaf"
    real_cp="$(command -v cp)"
    canonical_application="$(cd -- "$application" && pwd -P)"
    printf 'external sensitive marker\n' > "$TEST_TMPDIR/outside-marker"
    vendor_test_make_copy_race_stub

    bats_run env PATH="$TEST_TMPDIR/racing-cp-bin:$BASE_TEST_ORIG_PATH" \
        VENDOR_TEST_REAL_CP="$real_cp" \
        VENDOR_TEST_RACE_MODE=leaf \
        VENDOR_TEST_RACE_SOURCE="$canonical_application/VERSION" \
        VENDOR_TEST_RACE_BACKUP="$canonical_application/VERSION.original" \
        VENDOR_TEST_RACE_TARGET="$TEST_TMPDIR/outside-marker" \
        "$BASE_REPO_ROOT/scripts/vendor" standalone "$application" "$framework_bundle" "$destination"
    [ "$status" -eq 1 ]
    [[ "$output" == *"changed to a symlink while it was copied"* ]] || {
        printf 'Unexpected standalone staging output: %s\n' "$output" >&2
        false
    }
    [ ! -e "$destination" ]
    [ -f "$application/VERSION" ]
    [ ! -e "$application/VERSION.original" ]

    mkdir -p "$application/assets" "$TEST_TMPDIR/outside-assets"
    printf 'trusted runtime asset\n' > "$application/assets/runtime.txt"
    printf 'external sensitive marker\n' > "$TEST_TMPDIR/outside-assets/runtime.txt"
    destination="$TEST_TMPDIR/race-parent"
    bats_run env PATH="$TEST_TMPDIR/racing-cp-bin:$BASE_TEST_ORIG_PATH" \
        VENDOR_TEST_REAL_CP="$real_cp" \
        VENDOR_TEST_RACE_MODE=parent \
        VENDOR_TEST_RACE_SOURCE="$canonical_application/assets/runtime.txt" \
        VENDOR_TEST_RACE_PARENT="$canonical_application/assets" \
        VENDOR_TEST_RACE_BACKUP="$canonical_application/assets.original" \
        VENDOR_TEST_RACE_TARGET="$TEST_TMPDIR/outside-assets" \
        "$BASE_REPO_ROOT/scripts/vendor" standalone "$application" "$framework_bundle" "$destination" \
        --include assets/runtime.txt
    [ "$status" -eq 1 ]
    [[ "$output" == *"changed while it was copied"* ]] || {
        printf 'Unexpected standalone staging output: %s\n' "$output" >&2
        false
    }
    [ ! -e "$destination" ]
    [ -f "$application/assets/runtime.txt" ]
    [ ! -e "$application/assets.original" ]
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
