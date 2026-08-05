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
    "$@" >"$output_path" 2>&1
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

main() {
    local expected_major="${1-}" expected_minor="${2-}" expected_patch="${3-}"
    local script_dir repo_root release_script release_driver capture_path output_path
    local git_stub

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
    git_stub="$release_smoke_dir/git"
    cat >"$git_stub" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"show-ref --verify --quiet refs/tags/"* ]]; then
    exit 1
fi
if [[ "$*" == *"ls-remote --tags origin refs/tags/"* ]]; then
    exit 0
fi
printf 'Unexpected Git invocation in the Bash 4.2 release smoke: %s\n' "$*" >&2
exit 127
EOF
    chmod +x "$git_stub" || return 1
    PATH="$release_smoke_dir:$PATH"
    export PATH
    export BASE_BASH_RELEASE_BASECTL="$release_driver"
    export BASE_BASH_RELEASE_TEST_CAPTURE="$capture_path"

    if ! "$release_script" check --version 2.0.0-alpha.1 >"$output_path" 2>&1; then
        release_smoke_fail "a supported prerelease check was not delegated."
        return 1
    fi
    grep -Fx 'arg=<release>' "$capture_path" >/dev/null || return 1
    grep -Fx 'arg=<check>' "$capture_path" >/dev/null || return 1
    grep -Fx "arg=<$repo_root/base_manifest.yaml>" "$capture_path" >/dev/null || return 1

    release_smoke_expect_blocked "$capture_path" "$output_path" \
        "$release_script" check --version 1.5.0 || return 1
    release_smoke_expect_blocked "$capture_path" "$output_path" \
        "$release_script" publish --version 2.0.0 --yes || return 1
    release_smoke_expect_blocked "$capture_path" "$output_path" \
        "$release_script" publish --version 2.0.0 --manifest --dry-run --yes || return 1

    printf 'Bash release-guard smoke passed on Bash %s.\n' "$BASH_VERSION"
    return 0
}

main "$@"
