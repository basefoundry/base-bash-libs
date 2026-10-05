#!/usr/bin/env bash

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
cd "$repo_root" || exit 1

required=(
    docs/README.md
    docs/v2/quickstart.md
    docs/v2/architecture.md
    docs/v2/migration-v1.4-to-v2.md
    docs/ci-policy.md
    integrations.md
)
for file in "${required[@]}"; do
    [[ -f "$file" ]] || {
        printf 'Missing documentation contract file: %s\n' "$file" >&2
        exit 1
    }
done

if grep -R -n -E 'checkout[[:space:]]+main|/archive/refs/heads/main|git clone .*[^[:alnum:]]main([[:space:]]|$)' \
    docs/v2 README.md; then
    printf 'Adoption documentation must not install from an unreleased moving main branch.\n' >&2
    exit 1
fi

grep -F "export BASE_BASH_LIBS_REF='v2.0.0'" docs/v2/quickstart.md > /dev/null || {
    printf 'The v2 quickstart must use the published GA release reference.\n' >&2
    exit 1
}
grep -F 'b4243765726c133499feeabdc50154f99c0fec12' docs/v2/quickstart.md README.md > /dev/null || {
    printf 'The v2 quickstart and source-checkout example must pin the verified GA commit.\n' >&2
    exit 1
}
grep -F 'framework_launcher' docs/v2/quickstart.md > /dev/null || {
    printf "The v2 quickstart must use the verified launcher path.\n" >&2
    exit 1
}
grep -F 'init --profile standard --dir demo' docs/v2/quickstart.md > /dev/null || {
    printf "The v2 quickstart must use the launcher's --dir option.\n" >&2
    exit 1
}
if grep -F -- '--project demo' docs/v2/quickstart.md > /dev/null; then
    printf 'The v2 quickstart must not use the unsupported --project init option.\n' >&2
    exit 1
fi

grep -F 'v2/quickstart.md' docs/README.md > /dev/null || {
    printf 'Documentation link is missing: v2/quickstart.md\n' >&2
    exit 1
}
grep -F 'v2/architecture.md' docs/README.md > /dev/null || {
    printf 'Documentation link is missing: v2/architecture.md\n' >&2
    exit 1
}
grep -F 'v2/migration-v1.4-to-v2.md' docs/README.md > /dev/null || {
    printf 'Documentation link is missing: v2/migration-v1.4-to-v2.md\n' >&2
    exit 1
}
grep -F 'ci-policy.md' docs/README.md > /dev/null || {
    printf 'Documentation link is missing: ci-policy.md\n' >&2
    exit 1
}
for link in SECURITY.md docs/support-policy.md docs/threat-model.md; do
    grep -R -F "$link" docs/README.md README.md > /dev/null || {
        printf 'Documentation link is missing: %s\n' "$link" >&2
        exit 1
    }
done

release_process=docs/release-process.md
for release_contract_text in \
    'lib/bash/base-bash-libs.release' \
    'commit=unknown' \
    'candidate rehearsal' \
    'real merged commit' \
    'scripts/release refs --version X.Y.Z' \
    'scripts/release-artifact verify-remote --version X.Y.Z --commit "$release_commit"'; do
    grep -F "$release_contract_text" "$release_process" > /dev/null || {
        printf 'Release-process documentation is missing the required contract text: %s\n' \
            "$release_contract_text" >&2
        exit 1
    }
done

# Rehearse the documented source-metadata transition in an isolated fixture.
# The checked-in commit and dirty-state fields remain provenance placeholders;
# only the version is advanced before the artifact builder creates its staged copy.
release_fixture="$(mktemp -d "${TMPDIR:-/tmp}/base-bash-release-docs.XXXXXX")" || exit 1
release_fixture_cleanup() { rm -rf -- "$release_fixture"; }
trap release_fixture_cleanup EXIT
cp VERSION "$release_fixture/VERSION" || exit 1
cp lib/bash/base-bash-libs.release "$release_fixture/base-bash-libs.release" || exit 1
printf '2.2.0\n' >| "$release_fixture/VERSION" || exit 1
awk -v candidate=2.2.0 '
    /^version=/ { print "version=" candidate; next }
    { print }
' "$release_fixture/base-bash-libs.release" >| "$release_fixture/base-bash-libs.release.next" || exit 1
mv -- "$release_fixture/base-bash-libs.release.next" "$release_fixture/base-bash-libs.release" || exit 1
[[ "$(< "$release_fixture/VERSION")" == "$(sed -n 's/^version=//p' "$release_fixture/base-bash-libs.release")" ]] || {
    printf 'Release-preparation metadata fixture did not align VERSION and embedded version.\n' >&2
    exit 1
}
grep -Fx 'commit=unknown' "$release_fixture/base-bash-libs.release" > /dev/null || {
    printf 'Release-preparation metadata fixture must preserve commit=unknown.\n' >&2
    exit 1
}
grep -Fx 'dirty_state=unknown' "$release_fixture/base-bash-libs.release" > /dev/null || {
    printf 'Release-preparation metadata fixture must preserve dirty_state=unknown.\n' >&2
    exit 1
}

printf 'Documentation contract passed.\n'
