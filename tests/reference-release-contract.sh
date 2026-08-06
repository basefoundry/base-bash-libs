#!/usr/bin/env bash

# Networkless contract for reference-app release evidence. It accepts the
# pre-GA pending state but prevents placeholders from being treated as release
# evidence.

reference_release_repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
reference_release_evidence="$reference_release_repo_root/examples/reference-apps/release-evidence.yaml"
reference_release_fail() {
    printf 'Reference release contract failed: %s\n' "$*" >&2
    exit 1
}

[[ -f "$reference_release_evidence" ]] || reference_release_fail 'evidence manifest is missing'
grep -Fx 'schema_version: 1' "$reference_release_evidence" > /dev/null ||
    reference_release_fail 'schema version is not 1'
grep -Fx 'release_line: v2.0.0' "$reference_release_evidence" > /dev/null ||
    reference_release_fail 'release line is not v2.0.0'
grep -Fx 'rehearsal_command: examples/reference-apps/release-rehearsal.sh' \
    "$reference_release_evidence" > /dev/null || reference_release_fail 'rehearsal command is missing'

for app in installer release-helper ops-cli; do
    [[ -f "$reference_release_repo_root/examples/reference-apps/$app/bin/app" ]] ||
        reference_release_fail "missing $app launcher"
    [[ -f "$reference_release_repo_root/examples/reference-apps/$app/tests/app.bats" ]] ||
        reference_release_fail "missing $app failure suite"
done

platform_count="$(grep -Ec '^  - bash: ' "$reference_release_evidence")"
[[ "$platform_count" == 5 ]] || reference_release_fail "expected five platform rows, found $platform_count"
grep -Fx '  - no-external-production-use-claim' "$reference_release_evidence" > /dev/null ||
    reference_release_fail 'evidence must prohibit an external-production claim'
grep -Fx '  - no-unsupported-performance-claim' "$reference_release_evidence" > /dev/null ||
    reference_release_fail 'evidence must prohibit an unsupported performance claim'

if grep -E '^(  ref|  commit|  sha256): pending' "$reference_release_evidence" > /dev/null; then
    grep -Fx 'status: pending-ga-asset' "$reference_release_evidence" > /dev/null ||
        reference_release_fail 'placeholder references require pending-ga-asset status'
    printf 'Reference release contract passed: status=pending-ga-asset platforms=%s.\n' "$platform_count"
    exit 0
fi

grep -Fx 'status: verified' "$reference_release_evidence" > /dev/null ||
    reference_release_fail 'non-placeholder evidence must be marked verified'
grep -E '^  (commit|sha256): [[:xdigit:]]{40,64}$' "$reference_release_evidence" > /dev/null ||
    reference_release_fail 'verified evidence requires immutable identities'
printf 'Reference release contract passed: status=verified platforms=%s.\n' "$platform_count"
