#!/usr/bin/env bash

release_smoke_dir=""

release_smoke_fail() {
    printf 'Bash release-guard smoke failed: %s\n' "$*" >&2
    return 1
}

release_smoke_expect_blocked() {
    local capture_path="$1" output_path="$2"
    local status
    shift 2

    rm -f -- "$capture_path"
    "$@" > "$output_path" 2>&1
    status=$?
    if ((status == 0)); then
        release_smoke_fail "blocked release command returned success."
        return 1
    fi
    if [[ -e "$capture_path" ]]; then
        release_smoke_fail "blocked release command reached the delegated driver."
        return 1
    fi
    return 0
}

release_smoke_cleanup() {
    if [[ -n "${release_smoke_dir-}" && -d "$release_smoke_dir" ]]; then
        rm -rf -- "$release_smoke_dir"
    fi
}

git() {
    if [[ "$*" == *"show-ref --verify --quiet refs/tags/"* ]]; then
        return 1
    fi
    if [[ "$*" == *"ls-remote --tags origin refs/tags/"* ]]; then
        return 0
    fi
    printf 'Unexpected Git invocation in the Bash 4.2 release smoke: %s\n' "$*" >&2
    return 127
}

main() {
    local expected_major="${1-}" expected_minor="${2-}" expected_patch="${3-}"
    local script_dir repo_root release_script release_driver release_artifact
    local capture_path output_path artifact_output source_commit

    if (($# != 0 && $# != 3)); then
        release_smoke_fail "usage: $0 [expected-major expected-minor expected-patch]"
        return 1
    fi

    if (($# == 3)) &&
        [[ "${BASH_VERSINFO[0]}" != "$expected_major" ||
            "${BASH_VERSINFO[1]}" != "$expected_minor" ||
            "${BASH_VERSINFO[2]}" != "$expected_patch" ]]; then
        release_smoke_fail "expected Bash $expected_major.$expected_minor.$expected_patch; running $BASH_VERSION."
        return 1
    fi

    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || {
        release_smoke_fail "unable to resolve the tests directory."
        return 1
    }
    repo_root="$(cd -- "$script_dir/.." && pwd -P)" || {
        release_smoke_fail "unable to resolve the repository root."
        return 1
    }
    release_script="$repo_root/scripts/release"
    release_smoke_dir="$(mktemp -d "${TMPDIR:-/tmp}/base-bash-release-smoke.XXXXXX")" || {
        release_smoke_fail "unable to create the smoke workspace."
        return 1
    }
    trap release_smoke_cleanup EXIT

    release_driver="$repo_root/tests/fixtures/basectl-release-stub"
    capture_path="$release_smoke_dir/delegated.out"
    output_path="$release_smoke_dir/command.out"
    export -f git
    export BASE_BASH_RELEASE_BASECTL="$release_driver"
    export BASE_BASH_RELEASE_TEST_CAPTURE="$capture_path"

    if ! "$release_script" check --version 2.0.0-alpha.1 > "$output_path" 2>&1; then
        release_smoke_fail "a supported prerelease check was not delegated."
        return 1
    fi
    grep -Fx 'arg=<release>' "$capture_path" > /dev/null || return 1
    grep -Fx 'arg=<check>' "$capture_path" > /dev/null || return 1
    grep -Fx "arg=<$repo_root/base_manifest.yaml>" "$capture_path" > /dev/null || return 1

    release_smoke_expect_blocked "$capture_path" "$output_path" \
        "$release_script" check --version 1.5.0 || return 1

    rm -f -- "$capture_path"
    if ! "$release_script" publish --version 2.0.0 --yes > "$output_path" 2>&1; then
        release_smoke_fail "GA release command was not delegated."
        return 1
    fi
    if [[ ! -e "$capture_path" ]]; then
        release_smoke_fail "GA release command did not reach the delegated driver."
        return 1
    fi
    release_smoke_expect_blocked "$capture_path" "$output_path" \
        "$release_script" publish --version 2.0.0 --manifest --dry-run --yes || return 1

    # The release-artifact verifier is part of the minimum-Bash trust boundary,
    # not only a modern-host validation path. Remove the release-driver Git
    # seam before building and verifying a canonical offline fixture.
    unset -f git
    release_artifact="$repo_root/scripts/release-artifact"
    artifact_output="$release_smoke_dir/artifact"
    source_commit="$(command git -C "$repo_root" rev-parse --verify 'HEAD^{commit}' 2> /dev/null)" || {
        release_smoke_fail "unable to resolve the source commit for artifact verification."
        return 1
    }
    if ! "$release_artifact" build --version 2.0.0 --commit "$source_commit" \
        --output "$artifact_output" > "$output_path" 2>&1; then
        release_smoke_fail "canonical artifact build failed on Bash $BASH_VERSION."
        return 1
    fi
    if ! "$release_artifact" verify "$artifact_output" > "$output_path" 2>&1; then
        release_smoke_fail "canonical artifact verification failed on Bash $BASH_VERSION."
        return 1
    fi

    printf 'Bash release and artifact smoke passed on Bash %s.\n' "$BASH_VERSION"
    return 0
}

main "$@"
