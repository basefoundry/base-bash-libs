#!/usr/bin/env bash

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1

required_files=(
    README.md
    VERSION
    CHANGELOG.md
    CONTRIBUTING.md
    .github/pull_request_template.md
    .github/base-project.yml
    LICENSE
    NOTICE
    SECURITY.md
    base_manifest.yaml
    base_api_manifest.yaml
    docs/versioning-policy.md
    docs/README.md
    docs/v2/quickstart.md
    docs/v2/architecture.md
    docs/v2/migration-v1.4-to-v2.md
    integrations.md
    docs/support-policy.md
    docs/threat-model.md
    docs/v2-api-contract.md
    docs/v2-symbol-map.md
    docs/api-reference.md
    docs/api-manifest-schema.md
    docs/support-matrix.md
    docs/ci-policy.md
    docs/integrations.md
    integrations/bashly/base_bashly.sh
    integrations/bashly/example.sh
    integrations/bats/base_bats_helper.bash
    integrations/project-kit/.shellcheckrc
    integrations/project-kit/.editorconfig
    integrations/project-kit/shfmt.conf
    integrations/package-managers/registry.yaml
    integrations/compatibility.yaml
    docs/discovery/awesome-bash.md
    .github/workflows/project-intake.yml
    .github/ISSUE_TEMPLATE/config.yml
    .github/workflows/tests.yml
    bin/base-bash
    scripts/release
    scripts/api-manifest
    scripts/library-bundle
    scripts/vendor
    scripts/migrate-v2-symbols
    tests/fixtures/basectl-release-stub
    tests/bash-42-release-smoke.sh
    tests/bash-42-logging-smoke.sh
    tests/bash-option-contract.sh
    tests/compatibility-matrix.sh
    tests/artifact-contract.sh
    tests/property-contract.sh
    tests/benchmark-contract.sh
    tests/integration-release-contract.sh
    tests/concurrency-contract.sh
    tests/quality-contract.sh
    tests/shfmt-contract.sh
    tests/release-invariants.sh
    examples/std-usage.sh
    examples/cookbook-cleanup-temp.sh
    examples/cookbook-args-lists-strings.sh
    tests/release.bats
    tests/namespace-contract.bats
    tests/api-manifest.bats
    tests/consumer-kit/tests/consumer_kit.bats
    tests/library-bundle.bats
    tests/vendor.bats
    tests/lint-warnings.sh
    tests/docs-contract.sh
    tests/integrations.bats
    examples/reference-apps/README.md
    examples/reference-apps/installer/lib/app.sh
    examples/reference-apps/installer/tests/app.bats
    examples/reference-apps/release-helper/lib/app.sh
    examples/reference-apps/release-helper/tests/app.bats
    examples/reference-apps/ops-cli/lib/app.sh
    examples/reference-apps/ops-cli/tests/app.bats
    examples/reference-apps/verify.sh
    benchmarks/README.md
    benchmarks/reference-apps.sh
    tests/reference-apps.bats
    CODE_OF_CONDUCT.md
    ROADMAP.md
    docs/community.md
    docs/who-uses-base-bash.md
    docs/independent-validation.md
    .github/ISSUE_TEMPLATE/bug.yml
    .github/ISSUE_TEMPLATE/feature.yml
    .github/ISSUE_TEMPLATE/documentation.yml
    tests/community-contract.sh
    first-party-cutover.yaml
    docs/first-party-cutover.md
    scripts/first-party-cutover
    tests/first-party-cutover.bats
)

cd "$repo_root" || exit 1

run_stage() {
    local label="$1"
    local status
    shift

    if "$@"; then
        return 0
    else
        status=$?
    fi

    printf 'Validation stage failed: %s (exit %s).\n' "$label" "$status" >&2
    return "$status"
}

check_no_strict_mode() {
    local file matches status
    local strict_mode_files=(
        bin/base-bash
        scripts/release
        tests/fixtures/basectl-release-stub
        tests/bash-42-release-smoke.sh
        tests/bash-42-logging-smoke.sh
        tests/bash-option-contract.sh
        tests/compatibility-matrix.sh
        tests/artifact-contract.sh
        tests/property-contract.sh
        tests/benchmark-contract.sh
        tests/integration-release-contract.sh
        tests/concurrency-contract.sh
        tests/quality-contract.sh
        tests/shfmt-contract.sh
        tests/release-invariants.sh
        tests/validate.sh
        tests/lint-warnings.sh
        scripts/migrate-v2-symbols
        examples/*.sh
        lib/bash/*/lib_*.sh
    )

    for file in "${strict_mode_files[@]}"; do
        if matches="$(grep -n -E \
            '^[[:space:]]*set[[:space:]]+-[^[:space:]]*[eu]([[:space:]]|$)|^[[:space:]]*set[[:space:]]+-o[[:space:]]+(errexit|nounset|pipefail)([[:space:]]|$)|^[[:space:]]*set[[:space:]]+.*[[:space:]]pipefail([[:space:]]|$)' \
            "$file")"; then
            printf 'Strict mode is not allowed in production or validation shell file %s:\n%s\n' \
                "$file" "$matches" >&2
            return 1
        else
            status=$?
            if ((status != 1)); then
                printf 'Unable to inspect %s for strict mode (exit %s).\n' "$file" "$status" >&2
                return "$status"
            fi
        fi
    done
}

for file in "${required_files[@]}"; do
    [[ -f "$file" ]] || {
        printf 'Missing required file: %s\n' "$file" >&2
        exit 1
    }
done

manifest_artifacts="$(scripts/api-manifest artifact-paths)" || exit $?
while IFS= read -r file; do
    [[ -n "$file" ]] && required_files+=("$file")
done <<< "$manifest_artifacts"

manifest_module_paths="$(scripts/api-manifest module-paths)" || exit $?
while IFS=$'\t' read -r module_kind readme test_path; do
    [[ -n "$module_kind" && -n "$readme" && -n "$test_path" ]] || continue
    [[ -f "$test_path" ]] || {
        printf 'Documented BATS path does not exist: %s\n' "$test_path" >&2
        exit 1
    }
    [[ "$module_kind" != sourceable-library ]] && continue
    grep -F "$test_path" "$readme" > /dev/null || {
        printf 'README does not document its BATS path: %s -> %s\n' "$readme" "$test_path" >&2
        exit 1
    }
done <<< "$manifest_module_paths"

printf 'Repository baseline is present.\n'

run_stage "strict-mode guard" check_no_strict_mode || exit $?

run_stage "documentation contract" tests/docs-contract.sh || exit $?

version=""
IFS= read -r version < VERSION || {
    printf 'Unable to read VERSION.\n' >&2
    exit 1
}

readme_head="$(sed -n '1,16p' README.md | tr -d '\r')"
if ! printf '%s\n' "$readme_head" | grep -F "[![Tests](https://img.shields.io/github/actions/workflow/status/basefoundry/base-bash-libs/tests.yml?branch=main&label=tests)](https://github.com/basefoundry/base-bash-libs/actions/workflows/tests.yml)" > /dev/null; then
    printf 'README.md is missing the main-branch tests health badge.\n' >&2
    exit 1
fi
if ! printf '%s\n' "$readme_head" | grep -F "[![Release](https://img.shields.io/github/v/release/basefoundry/base-bash-libs?sort=semver&label=release)](https://github.com/basefoundry/base-bash-libs/releases)" > /dev/null; then
    printf 'README.md is missing the GitHub release badge.\n' >&2
    exit 1
fi
if ! printf '%s\n' "$readme_head" | grep -F "[![Bash](https://img.shields.io/badge/Bash-4.2%2B-4EAA25?logo=gnubash&logoColor=white)](docs/support-matrix.md)" > /dev/null; then
    printf 'README.md is missing the supported Bash version badge.\n' >&2
    exit 1
fi

if [[ ! "$version" =~ ^[0-9]+[.][0-9]+[.][0-9]+(-[0-9A-Za-z.-]+)?([+][0-9A-Za-z.-]+)?$ ]]; then
    printf 'VERSION is not a SemVer-compatible version: %s\n' "$version" >&2
    exit 1
fi

version_core="${version%%[-+]*}"
latest_tag_core="0.0.0"
while IFS= read -r tag; do
    tag_version="${tag#v}"
    tag_core="${tag_version%%[-+]*}"
    [[ "$tag_core" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]] || continue
    IFS=. read -r tag_major tag_minor tag_patch <<< "$tag_core"
    IFS=. read -r latest_major latest_minor latest_patch <<< "$latest_tag_core"
    if ((tag_major > latest_major)) ||
        ((tag_major == latest_major && tag_minor > latest_minor)) ||
        ((tag_major == latest_major && tag_minor == latest_minor && tag_patch > latest_patch)); then
        latest_tag_core="$tag_core"
    fi
done < <(git tag --list 'v[0-9]*' 2> /dev/null)
IFS=. read -r version_major version_minor version_patch <<< "$version_core"
IFS=. read -r latest_major latest_minor latest_patch <<< "$latest_tag_core"
if ((version_major < latest_major)) ||
    ((version_major == latest_major && version_minor < latest_minor)) ||
    ((version_major == latest_major && version_minor == latest_minor && version_patch < latest_patch)); then
    printf 'VERSION %s moves behind the highest existing release tag v%s.\n' \
        "$version" "$latest_tag_core" >&2
    exit 1
fi

release_metadata_version="$(sed -n 's/^version=//p' lib/bash/base-bash-libs.release | sed -n '1p')"
if [[ "$release_metadata_version" != "$version" ]]; then
    printf 'Embedded release metadata version (%s) does not match VERSION (%s).\n' \
        "$release_metadata_version" "$version" >&2
    exit 1
fi
for metadata_key in schema_version version commit dirty_state provenance; do
    metadata_count="$(grep -c -E "^${metadata_key}=" lib/bash/base-bash-libs.release || true)"
    [[ "$metadata_count" == 1 ]] || {
        printf 'Embedded release metadata must contain exactly one %s key (found %s).\n' \
            "$metadata_key" "$metadata_count" >&2
        exit 1
    }
    grep -E "^${metadata_key}=.+$" lib/bash/base-bash-libs.release > /dev/null || {
        printf 'Embedded release metadata is missing key: %s\n' "$metadata_key" >&2
        exit 1
    }
done

release_metadata_schema="$(sed -n 's/^schema_version=//p' lib/bash/base-bash-libs.release)"
release_metadata_commit="$(sed -n 's/^commit=//p' lib/bash/base-bash-libs.release)"
release_metadata_dirty="$(sed -n 's/^dirty_state=//p' lib/bash/base-bash-libs.release)"
release_metadata_provenance="$(sed -n 's/^provenance=//p' lib/bash/base-bash-libs.release)"
[[ "$release_metadata_schema" == 1 ]] || {
    printf 'Embedded release metadata schema_version must be 1.\n' >&2
    exit 1
}
[[ "$release_metadata_commit" == unknown || "$release_metadata_commit" =~ ^[[:xdigit:]]{40}$ ]] || {
    printf 'Embedded release metadata commit must be a full SHA or unknown.\n' >&2
    exit 1
}
[[ "$release_metadata_dirty" =~ ^(clean|dirty|unknown)$ ]] || {
    printf 'Embedded release metadata dirty_state must be clean, dirty, or unknown.\n' >&2
    exit 1
}
[[ "$release_metadata_provenance" =~ ^(checkout|release-artifact|source-archive|copy|unknown)$ ]] || {
    printf 'Embedded release metadata provenance is not recognized: %s\n' \
        "$release_metadata_provenance" >&2
    exit 1
}

release_metadata_unknown_keys="$(grep -v -E '^(schema_version|version|commit|dirty_state|provenance)=' \
    lib/bash/base-bash-libs.release || true)"
if [[ -n "$release_metadata_unknown_keys" ]]; then
    printf 'Embedded release metadata contains unknown keys:\n%s\n' \
        "$release_metadata_unknown_keys" >&2
    exit 1
fi

if [[ "$(grep -c '^## \[Unreleased\]' CHANGELOG.md)" != 1 ]]; then
    printf 'CHANGELOG.md must contain exactly one [Unreleased] section.\n' >&2
    exit 1
fi
if [[ "$(grep -c -F "## [$version]" CHANGELOG.md)" -gt 1 ]]; then
    printf 'CHANGELOG.md contains duplicate release sections for %s.\n' "$version" >&2
    exit 1
fi

if ! grep -F "| \`$version\` | [Apache-2.0](LICENSE) |" README.md > /dev/null; then
    printf 'README.md top strip does not match VERSION (%s) and Apache-2.0 license metadata.\n' "$version" >&2
    exit 1
fi

if ! sed -n '1,30p' README.md | grep -F 'Requires Bash 4.2+' > /dev/null; then
    printf 'README.md must state the Bash 4.2+ requirement near the top-level entry point.\n' >&2
    exit 1
fi

stale_base_refs="$(grep -R -n -E 'codeforester/base|github.com/codeforester' README.md lib/bash/README.md || true)"
if [[ -n "$stale_base_refs" ]]; then
    printf 'README files must not use stale codeforester Base coordinates:\n%s\n' "$stale_base_refs" >&2
    exit 1
fi

if ! grep -F '      - main' .github/workflows/tests.yml > /dev/null; then
    printf 'Tests workflow must run push validation on the main branch.\n' >&2
    exit 1
fi

if grep -F 'secrets.BASE_PROJECT_TOKEN || github.token' .github/workflows/project-intake.yml > /dev/null; then
    printf 'Project intake workflow must not fall back to github.token for org Project writes.\n' >&2
    exit 1
fi

if ! grep -F 'GH_TOKEN: ${{ secrets.BASE_PROJECT_TOKEN }}' .github/workflows/project-intake.yml > /dev/null; then
    printf 'Project intake workflow must use BASE_PROJECT_TOKEN directly for gh commands.\n' >&2
    exit 1
fi

if ! grep -F 'BASE_PROJECT_MIN_GRAPHQL_REMAINING' .github/workflows/project-intake.yml > /dev/null; then
    printf 'Project intake workflow must define a minimum GraphQL quota before Project mutations.\n' >&2
    exit 1
fi

if ! grep -F 'rateLimit { remaining resetAt }' .github/workflows/project-intake.yml > /dev/null; then
    printf 'Project intake workflow must check GitHub GraphQL quota before Project mutations.\n' >&2
    exit 1
fi

if ! grep -F 'Project intake backfill' CONTRIBUTING.md > /dev/null; then
    printf 'CONTRIBUTING.md must document the throttled Project intake backfill workflow.\n' >&2
    exit 1
fi

if ! grep -F 'gh workflow run project-intake.yml' CONTRIBUTING.md > /dev/null; then
    printf 'CONTRIBUTING.md must include the manual Project intake workflow dispatch command.\n' >&2
    exit 1
fi

fix_comments="$(grep -R -n '# FIX:' lib/bash || true)"
if [[ -n "$fix_comments" ]]; then
    printf 'Production library files must not contain development # FIX: comments:\n%s\n' "$fix_comments" >&2
    exit 1
fi

for command in shellcheck bats; do
    command -v "$command" > /dev/null 2>&1 || {
        printf "Required validation command '%s' was not found.\n" "$command" >&2
        exit 1
    }
done

manifest_source_paths="$(scripts/api-manifest source-paths)" || exit $?
manifest_shellcheck_paths=()
while IFS= read -r file; do
    [[ -n "$file" ]] && manifest_shellcheck_paths+=("$file")
done <<< "$manifest_source_paths"

run_stage "ShellCheck error profile" shellcheck --severity=error \
    bin/base-bash \
    scripts/api-manifest \
    scripts/library-bundle \
    scripts/vendor \
    scripts/release \
    scripts/migrate-v2-symbols \
    tests/fixtures/basectl-release-stub \
    tests/bash-42-release-smoke.sh \
    tests/bash-42-logging-smoke.sh \
    tests/bash-option-contract.sh \
    tests/compatibility-matrix.sh \
    tests/artifact-contract.sh \
    tests/property-contract.sh \
    tests/benchmark-contract.sh \
    tests/integration-release-contract.sh \
    tests/concurrency-contract.sh \
    tests/quality-contract.sh \
    tests/shfmt-contract.sh \
    tests/release-invariants.sh \
    tests/validate.sh \
    tests/lint-warnings.sh \
    examples/std-usage.sh \
    examples/cookbook-cleanup-temp.sh \
    examples/cookbook-args-lists-strings.sh \
    lib/bash/tests/test_helper.sh \
    "${manifest_shellcheck_paths[@]}" \
    tests/release.bats \
    tests/namespace-contract.bats \
    tests/api-manifest.bats \
    tests/consumer-kit/test_helper.bash \
    tests/consumer-kit/tests/consumer_kit.bats \
    tests/library-bundle.bats \
    tests/vendor.bats \
    integrations/bashly/base_bashly.sh \
    integrations/bashly/example.sh \
    integrations/bats/base_bats_helper.bash \
    tests/integrations.bats \
    examples/reference-apps/installer/lib/app.sh \
    examples/reference-apps/release-helper/lib/app.sh \
    examples/reference-apps/ops-cli/lib/app.sh \
    examples/reference-apps/verify.sh \
    benchmarks/reference-apps.sh \
    tests/reference-apps.bats \
    tests/community-contract.sh \
    scripts/first-party-cutover \
    tests/first-party-cutover.bats

bats_files=(
    tests/release.bats
    tests/namespace-contract.bats
    tests/api-manifest.bats
    tests/consumer-kit/tests/consumer_kit.bats
    tests/library-bundle.bats
    tests/vendor.bats
    tests/integrations.bats
    tests/reference-apps.bats
    tests/first-party-cutover.bats
)
manifest_test_paths="$(scripts/api-manifest test-paths)" || exit $?
while IFS= read -r file; do
    [[ -n "$file" ]] && bats_files+=("$file")
done <<< "$manifest_test_paths"

run_stage "BATS test suites" bats \
    "${bats_files[@]}" || exit $?

run_stage "Bash logging smoke" tests/bash-42-logging-smoke.sh || exit $?
run_stage "Bash release guard smoke" tests/bash-42-release-smoke.sh || exit $?
run_stage "Bash caller-option contract" tests/bash-option-contract.sh || exit $?
run_stage "deterministic property contract" tests/property-contract.sh || exit $?
run_stage "distribution artifact contract" tests/artifact-contract.sh || exit $?
run_stage "benchmark contract" tests/benchmark-contract.sh || exit $?
run_stage "integration release contract" tests/integration-release-contract.sh || exit $?
run_stage "concurrency contract" tests/concurrency-contract.sh || exit $?
run_stage "quality workflow contract" tests/quality-contract.sh || exit $?
run_stage "support matrix" tests/compatibility-matrix.sh || exit $?
run_stage "release invariants" tests/release-invariants.sh || exit $?
run_stage "examples/std-usage.sh" examples/std-usage.sh > /dev/null || exit $?
run_stage "examples/cookbook-cleanup-temp.sh" examples/cookbook-cleanup-temp.sh > /dev/null || exit $?
run_stage "examples/cookbook-args-lists-strings.sh" examples/cookbook-args-lists-strings.sh > /dev/null || exit $?
run_stage "Bashly integration example" integrations/bashly/example.sh candidate > /dev/null || exit $?
run_stage "reference application smoke" examples/reference-apps/verify.sh > /dev/null || exit $?
run_stage "community contract" tests/community-contract.sh > /dev/null || exit $?
run_stage "first-party cutover pending check" scripts/first-party-cutover check --allow-pending > /dev/null || exit $?

printf 'Bash library validation passed.\n'
