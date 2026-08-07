#!/usr/bin/env bash

# Networkless release-gate smoke for immutable metadata and deterministic
# artifacts. This intentionally uses only repository-local inputs.

invariant_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
invariant_repo_root="$(cd -- "$invariant_script_dir/.." && pwd -P)" || exit 1
invariant_tmp="$(mktemp -d "${TMPDIR:-/tmp}/base-bash-release.XXXXXX")" || exit 1

invariant_cleanup() {
    rm -rf -- "$invariant_tmp"
}
trap invariant_cleanup EXIT

invariant_fail() {
    printf 'Release invariant failed: %s\n' "$*" >&2
    exit 1
}

cd "$invariant_repo_root" || invariant_fail "unable to enter repository"
scripts/api-manifest check > /dev/null || invariant_fail "API manifest check failed"
scripts/library-bundle check > /dev/null || invariant_fail "library bundle check failed"
scripts/library-bundle bundle "$invariant_tmp/bundle" > /dev/null || invariant_fail "bundle creation failed"
scripts/library-bundle verify "$invariant_tmp/bundle" > /dev/null || invariant_fail "bundle verification failed"

while IFS= read -r workflow; do
    [[ -n "$workflow" ]] || continue
    while IFS= read -r action_ref; do
        [[ -n "$action_ref" ]] || continue
        [[ "$action_ref" =~ @[0-9a-f]{40}([[:space:]]|$) ]] ||
            invariant_fail "workflow action is not pinned: $workflow: $action_ref"
    done < <(grep -E '^[[:space:]]*-[[:space:]]*uses:[[:space:]]*[^#]+' "$workflow" || true)
done < <(find .github/workflows -type f -name '*.yml' -print | sort)

grep -F 'docker.io/library/bash@sha256:69d156705ff4829e60cd958dd356e8db024195efcdb0504eb3426c84647c6e88' \
    tests/compatibility-matrix.sh > /dev/null ||
    invariant_fail 'Alpine/musl Bash image is not immutable-pinned'

printf 'Release invariants passed; deterministic bundle verified at %s.\n' "$invariant_tmp/bundle"
