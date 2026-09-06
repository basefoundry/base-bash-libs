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
invariant_candidate_version="$(sed -n '1p' VERSION 2> /dev/null || true)"
[[ -n "$invariant_candidate_version" ]] || invariant_fail "unable to read VERSION"
invariant_ga_tag="$(sed -n 's/^  tag: //p' first-party-cutover.yaml | sed -n '1p')"
[[ "$invariant_ga_tag" =~ ^v[0-9]+[.][0-9]+[.][0-9]+([-.][[:alnum:].-]+)?$ ]] ||
    invariant_fail "first-party-cutover.yaml does not declare a valid GA tag"

invariant_release_ref="${BASE_BASH_LIBS_RELEASE_REF:-}"
invariant_release_ref_source=""
if [[ -n "$invariant_release_ref" ]]; then
    invariant_release_ref_source="BASE_BASH_LIBS_RELEASE_REF override"
elif [[ "$invariant_candidate_version" == "${invariant_ga_tag#v}" ]]; then
    invariant_release_ref="$invariant_ga_tag"
    invariant_release_ref_source="published GA tag from first-party-cutover.yaml"
else
    # A release-preparation checkout changes VERSION before its candidate tag
    # exists. HEAD is the only local ref shared by the documented local and CI
    # commands, and it contains the candidate manifest and source tree.
    invariant_release_ref=HEAD
    invariant_release_ref_source="candidate checkout (VERSION $invariant_candidate_version differs from $invariant_ga_tag)"
fi
printf 'Release invariant API reference: candidate_version=%s release_ref=%s provenance=%s\n' \
    "$invariant_candidate_version" "$invariant_release_ref" "$invariant_release_ref_source"
scripts/api-manifest check > /dev/null || invariant_fail "API manifest check failed"
if ! invariant_release_check_output="$(scripts/api-manifest release-check "$invariant_release_ref" 2>&1)"; then
    printf '%s\n' "$invariant_release_check_output" >&2
    invariant_fail "stable API is not present in release_ref=$invariant_release_ref (provenance=$invariant_release_ref_source)"
fi
printf '%s\n' "$invariant_release_check_output"
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
