#!/usr/bin/env bats

load ../lib/bash/tests/test_helper.sh

setup() {
    setup_test_tmpdir
    RELEASE_SCRIPT="$BASE_REPO_ROOT/scripts/release"
    RELEASE_DRIVER="$BASE_REPO_ROOT/tests/fixtures/basectl-release-stub"
    RELEASE_CAPTURE="$TEST_TMPDIR/release-driver.out"
    RELEASE_PUBLISH_MARKER="$TEST_TMPDIR/actual-publish"
    PATH="$BASE_TEST_ORIG_PATH"
    export PATH
    RELEASE_REAL_GIT="$(command -v git)"
    RELEASE_GIT_STUB="$TEST_TMPDIR/git"
    export BASE_BASH_RELEASE_BASECTL="$RELEASE_DRIVER"
    export BASE_BASH_RELEASE_TEST_CAPTURE="$RELEASE_CAPTURE"
    export BASE_BASH_RELEASE_TEST_PUBLISH_MARKER="$RELEASE_PUBLISH_MARKER"
    export BASE_BASH_RELEASE_TEST_LOCAL_TAG=""
    export BASE_BASH_RELEASE_TEST_REMOTE_TAG=""
    export BASE_BASH_RELEASE_TEST_REMOTE_STATUS="ok"
    export BASE_BASH_RELEASE_REAL_GIT="$RELEASE_REAL_GIT"

    cat >"$RELEASE_GIT_STUB" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"show-ref --verify --quiet refs/tags/"* ]]; then
    if [[ "${BASE_BASH_RELEASE_TEST_LOCAL_TAG:-}" == present ]]; then
        exit 0
    fi
    exit 1
fi
if [[ "$*" == *"ls-remote --tags origin refs/tags/"* ]]; then
    if [[ "${BASE_BASH_RELEASE_TEST_REMOTE_STATUS:-ok}" == error ]]; then
        exit 2
    fi
    if [[ "${BASE_BASH_RELEASE_TEST_REMOTE_TAG:-}" == present ]]; then
        printf 'deadbeef refs/tags/%s\n' "${*##*refs/tags/}"
    fi
    exit 0
fi
exec "${BASE_BASH_RELEASE_REAL_GIT}" "$@"
EOF
    chmod +x "$RELEASE_GIT_STUB"
    PATH="$TEST_TMPDIR:$BASE_TEST_ORIG_PATH"
    export PATH
}

assert_driver_not_called() {
    [ ! -e "$RELEASE_CAPTURE" ]
}

@test "release guard delegates supported prerelease checks from the repository root" {
    bats_run "$RELEASE_SCRIPT" check --version 2.0.0-alpha.1 \
        --manifest "$BASE_REPO_ROOT/base_manifest.yaml"

    [ "$status" -eq 0 ]
    [ "$output" = "" ]
    grep -F "cwd=<$BASE_REPO_ROOT>" "$RELEASE_CAPTURE"
    grep -Fx 'arg=<release>' "$RELEASE_CAPTURE"
    grep -Fx 'arg=<check>' "$RELEASE_CAPTURE"
    grep -Fx 'arg=<--version>' "$RELEASE_CAPTURE"
    grep -Fx 'arg=<2.0.0-alpha.1>' "$RELEASE_CAPTURE"
    grep -Fx 'arg=<--manifest>' "$RELEASE_CAPTURE"
    grep -Fx "arg=<$BASE_REPO_ROOT/base_manifest.yaml>" "$RELEASE_CAPTURE"
}

@test "release guard injects the canonical manifest when it is omitted" {
    bats_run "$RELEASE_SCRIPT" plan --version 2.0.0-alpha.1

    [ "$status" -eq 0 ]
    grep -Fx 'arg=<--manifest>' "$RELEASE_CAPTURE"
    grep -Fx "arg=<$BASE_REPO_ROOT/base_manifest.yaml>" "$RELEASE_CAPTURE"
}

@test "release guard accepts every defined prerelease phase" {
    local version

    for version in 2.0.0-alpha.9 2.0.1-beta.10 2.1.0-rc.3; do
        rm -f "$RELEASE_CAPTURE"
        bats_run "$RELEASE_SCRIPT" plan --version "$version"

        [ "$status" -eq 0 ]
        grep -Fx "arg=<$version>" "$RELEASE_CAPTURE"
    done
}

@test "release guard preserves the delegated exit status" {
    export BASE_BASH_RELEASE_TEST_STATUS=17

    bats_run "$RELEASE_SCRIPT" notes --version 2.0.0-rc.1

    [ "$status" -eq 17 ]
}

@test "release guard rejects stable 0.x and 1.x releases" {
    local version

    for version in 0.9.0 1.4.0 1.4.1 1.5.0; do
        bats_run "$RELEASE_SCRIPT" check --version "$version"

        [ "$status" -eq 1 ]
        [[ "$output" == *"outside the supported Base Bash v2 release policy"* ]]
    done
    assert_driver_not_called
}

@test "release guard rejects malformed and unplanned v2 identifiers" {
    local version

    for version in \
        2.0.0-alpha.0 \
        2.0.0-alpha.01 \
        2.0.0-preview.1 \
        2.0.0-alpha \
        2.0.0-alpha.1+build.1 \
        2.00.0 \
        2.0.01 \
        2.01.0 \
        2.1.0-rc.0 \
        2.1.0-rc.01 \
        2.1.0+build.1 \
        3.0.0; do
        bats_run "$RELEASE_SCRIPT" check --version "$version"

        [ "$status" -eq 1 ]
    done
    assert_driver_not_called
}

@test "release guard delegates post-GA patch and minor workflows" {
    local version command

    for version in 2.0.1 2.1.0; do
        bats_run "$RELEASE_SCRIPT" refs --version "$version"
        [ "$status" -eq 0 ]
        [[ "$output" == *"v$version is absent locally and on origin"* ]]

        for command in check plan notes; do
            rm -f "$RELEASE_CAPTURE"
            bats_run "$RELEASE_SCRIPT" "$command" --version "$version"
            [ "$status" -eq 0 ]
            grep -Fx "arg=<$command>" "$RELEASE_CAPTURE"
            grep -Fx "arg=<$version>" "$RELEASE_CAPTURE"
        done

        rm -f "$RELEASE_CAPTURE"
        bats_run "$RELEASE_SCRIPT" publish --version "$version" --dry-run
        [ "$status" -eq 0 ]
        grep -Fx 'arg=<publish>' "$RELEASE_CAPTURE"
        grep -Fx "arg=<$version>" "$RELEASE_CAPTURE"
        grep -Fx 'arg=<--dry-run>' "$RELEASE_CAPTURE"
        [ ! -e "$RELEASE_PUBLISH_MARKER" ]
    done
}

@test "release guard delegates real prerelease publication after the artifact gate" {
    bats_run "$RELEASE_SCRIPT" publish --version 2.0.0-beta.1 --yes

    [ "$status" -eq 0 ]
    grep -Fx 'arg=<publish>' "$RELEASE_CAPTURE"
    grep -Fx 'arg=<--version>' "$RELEASE_CAPTURE"
    grep -Fx 'arg=<2.0.0-beta.1>' "$RELEASE_CAPTURE"
    grep -Fx 'arg=<--yes>' "$RELEASE_CAPTURE"
    [ -e "$RELEASE_PUBLISH_MARKER" ]
}

@test "release guard delegates real v2 GA publication after reviewed RC gates" {
    bats_run "$RELEASE_SCRIPT" publish --version 2.0.0 --yes

    [ "$status" -eq 0 ]
    grep -Fx 'arg=<publish>' "$RELEASE_CAPTURE"
    grep -Fx 'arg=<--version>' "$RELEASE_CAPTURE"
    grep -Fx 'arg=<2.0.0>' "$RELEASE_CAPTURE"
    grep -Fx 'arg=<--yes>' "$RELEASE_CAPTURE"
    [ -e "$RELEASE_PUBLISH_MARKER" ]
}

@test "release refs preflight accepts an unused candidate tag" {
    bats_run "$RELEASE_SCRIPT" refs --version 2.0.0

    [ "$status" -eq 0 ]
    [[ "$output" == *"v2.0.0 is absent locally and on origin"* ]]
}

@test "release refs preflight rejects a conflicting local tag" {
    export BASE_BASH_RELEASE_TEST_LOCAL_TAG=present

    bats_run "$RELEASE_SCRIPT" refs --version 2.0.0

    [ "$status" -eq 1 ]
    [[ "$output" == *"already exists in the local repository"* ]]
    [[ "$output" == *"never retag a published release"* ]]
}

@test "release refs preflight rejects a conflicting remote tag" {
    export BASE_BASH_RELEASE_TEST_REMOTE_TAG=present

    bats_run "$RELEASE_SCRIPT" refs --version 2.0.0

    [ "$status" -eq 1 ]
    [[ "$output" == *"already exists on origin"* ]]
    [[ "$output" == *"Published tags are immutable"* ]]
}

@test "release refs preflight fails closed when origin cannot be inspected" {
    export BASE_BASH_RELEASE_TEST_REMOTE_STATUS=error

    bats_run "$RELEASE_SCRIPT" refs --version 2.0.0

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unable to inspect release tag 'v2.0.0' on origin"* ]]
    assert_driver_not_called
}

@test "release guard does not mistake a manifest value for a dry-run flag" {
    bats_run "$RELEASE_SCRIPT" publish --version 2.0.0 --manifest --dry-run --yes

    [ "$status" -eq 1 ]
    [[ "$output" == *"must use the canonical manifest"* ]]
    assert_driver_not_called
    [ ! -e "$RELEASE_PUBLISH_MARKER" ]
}

@test "release guard rejects alternate and external manifests" {
    local manifest_path

    for manifest_path in alternate.yaml ../base_manifest.yaml "$TEST_TMPDIR/base_manifest.yaml"; do
        bats_run "$RELEASE_SCRIPT" check --version 2.0.0-rc.1 --manifest "$manifest_path"

        [ "$status" -eq 1 ]
        [[ "$output" == *"must use the canonical manifest"* ]]
    done
    assert_driver_not_called
}

@test "release guard delegates prerelease publish dry runs without losing arguments" {
    bats_run "$RELEASE_SCRIPT" publish --yes --version 2.0.0-rc.4 --dry-run

    [ "$status" -eq 0 ]
    grep -Fx 'arg=<publish>' "$RELEASE_CAPTURE"
    grep -Fx 'arg=<--yes>' "$RELEASE_CAPTURE"
    grep -Fx 'arg=<--version>' "$RELEASE_CAPTURE"
    grep -Fx 'arg=<2.0.0-rc.4>' "$RELEASE_CAPTURE"
    grep -Fx 'arg=<--dry-run>' "$RELEASE_CAPTURE"
}

@test "release guard allows GA readiness and dry-run inspection without publishing" {
    bats_run "$RELEASE_SCRIPT" check --version 2.0.0
    [ "$status" -eq 0 ]

    rm -f "$RELEASE_CAPTURE"
    bats_run "$RELEASE_SCRIPT" publish --version 2.0.0 --dry-run
    [ "$status" -eq 0 ]
    grep -Fx 'arg=<--dry-run>' "$RELEASE_CAPTURE"
}

@test "release guard rejects missing versions and unknown commands as usage errors" {
    bats_run "$RELEASE_SCRIPT" check
    [ "$status" -eq 2 ]
    [[ "$output" == *"require --version"* ]]

    bats_run "$RELEASE_SCRIPT" deploy --version 2.0.0-rc.1
    [ "$status" -eq 2 ]
    [[ "$output" == *"Unknown release command"* ]]
    assert_driver_not_called
}

@test "release guard fails closed on duplicate and unsupported options" {
    bats_run "$RELEASE_SCRIPT" publish --version 2.0.0 --version 2.0.0 --dry-run
    [ "$status" -eq 2 ]
    [[ "$output" == *"Option '--version' may be provided only once."* ]]

    bats_run "$RELEASE_SCRIPT" publish --version 2.0.0 --force --dry-run
    [ "$status" -eq 2 ]
    [[ "$output" == *"Unknown release publish option '--force'"* ]]

    bats_run "$RELEASE_SCRIPT" check --version 2.0.0 --dry-run
    [ "$status" -eq 2 ]
    [[ "$output" == *"Option '--dry-run' is only supported by release publish."* ]]
    assert_driver_not_called
}
