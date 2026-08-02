#!/usr/bin/env bats

load ../lib/bash/tests/test_helper.sh

setup() {
    setup_test_tmpdir
    RELEASE_SCRIPT="$BASE_REPO_ROOT/scripts/release"
    RELEASE_DRIVER="$BASE_REPO_ROOT/tests/fixtures/basectl-release-stub"
    RELEASE_CAPTURE="$TEST_TMPDIR/release-driver.out"
    RELEASE_PUBLISH_MARKER="$TEST_TMPDIR/actual-publish"
    export BASE_BASH_RELEASE_BASECTL="$RELEASE_DRIVER"
    export BASE_BASH_RELEASE_TEST_CAPTURE="$RELEASE_CAPTURE"
    export BASE_BASH_RELEASE_TEST_PUBLISH_MARKER="$RELEASE_PUBLISH_MARKER"

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

    for version in 2.0.0-alpha.9 2.0.0-beta.10 2.0.0-rc.3; do
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
        [[ "$output" == *"outside the Base Bash v2.0.0 release line"* ]]
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
        2.0.1 \
        2.1.0 \
        3.0.0; do
        bats_run "$RELEASE_SCRIPT" check --version "$version"

        [ "$status" -eq 1 ]
    done
    assert_driver_not_called
}

@test "release guard locks real prerelease publication" {
    bats_run "$RELEASE_SCRIPT" publish --version 2.0.0-beta.1 --yes

    [ "$status" -eq 1 ]
    [[ "$output" == *"locked until verified release artifacts and provenance land in #233"* ]]
    assert_driver_not_called
}

@test "release guard locks real v2 GA publication" {
    bats_run "$RELEASE_SCRIPT" publish --version 2.0.0 --yes

    [ "$status" -eq 1 ]
    [[ "$output" == *"#240 RC rehearsal"* ]]
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
