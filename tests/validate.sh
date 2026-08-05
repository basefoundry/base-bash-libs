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
  base_manifest.yaml
  base_api_manifest.yaml
  docs/versioning-policy.md
  docs/v2-api-contract.md
  docs/v2-symbol-map.md
  docs/api-reference.md
  docs/api-manifest-schema.md
  .github/workflows/project-intake.yml
  .github/workflows/tests.yml
  bin/base-bash
  scripts/release
  scripts/api-manifest
  scripts/migrate-v2-symbols
  tests/fixtures/basectl-release-stub
  tests/bash-42-release-smoke.sh
  tests/bash-42-logging-smoke.sh
  tests/bash-option-contract.sh
  examples/std-usage.sh
  examples/cookbook-cleanup-temp.sh
  examples/cookbook-args-lists-strings.sh
  tests/release.bats
  tests/namespace-contract.bats
  tests/api-manifest.bats
  tests/lint-warnings.sh
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
done <<<"$manifest_artifacts"

manifest_module_paths="$(scripts/api-manifest module-paths)" || exit $?
while IFS=$'\t' read -r module_kind readme test_path; do
  [[ -n "$module_kind" && -n "$readme" && -n "$test_path" ]] || continue
  [[ -f "$test_path" ]] || {
    printf 'Documented BATS path does not exist: %s\n' "$test_path" >&2
    exit 1
  }
  [[ "$module_kind" != sourceable-library ]] && continue
  grep -F "$test_path" "$readme" >/dev/null || {
    printf 'README does not document its BATS path: %s -> %s\n' "$readme" "$test_path" >&2
    exit 1
  }
done <<<"$manifest_module_paths"

printf 'Repository baseline is present.\n'

run_stage "strict-mode guard" check_no_strict_mode || exit $?

version=""
IFS= read -r version < VERSION || {
  printf 'Unable to read VERSION.\n' >&2
  exit 1
}

release_metadata_version="$(sed -n 's/^version=//p' lib/bash/base-bash-libs.release | sed -n '1p')"
if [[ "$release_metadata_version" != "$version" ]]; then
  printf 'Embedded release metadata version (%s) does not match VERSION (%s).\n' \
    "$release_metadata_version" "$version" >&2
  exit 1
fi
for metadata_key in schema_version version commit dirty_state provenance; do
  grep -E "^${metadata_key}=.+$" lib/bash/base-bash-libs.release >/dev/null || {
    printf 'Embedded release metadata is missing key: %s\n' "$metadata_key" >&2
    exit 1
  }
done

if ! grep -F "| \`$version\` | [Apache-2.0](LICENSE) |" README.md >/dev/null; then
  printf 'README.md top strip does not match VERSION (%s) and Apache-2.0 license metadata.\n' "$version" >&2
  exit 1
fi

if ! sed -n '1,30p' README.md | grep -F 'Requires Bash 4.2+' >/dev/null; then
  printf 'README.md must state the Bash 4.2+ requirement near the top-level entry point.\n' >&2
  exit 1
fi

stale_base_refs="$(grep -R -n -E 'codeforester/base|github.com/codeforester' README.md lib/bash/README.md || true)"
if [[ -n "$stale_base_refs" ]]; then
  printf 'README files must not use stale codeforester Base coordinates:\n%s\n' "$stale_base_refs" >&2
  exit 1
fi

if ! grep -F '      - main' .github/workflows/tests.yml >/dev/null; then
  printf 'Tests workflow must run push validation on the main branch.\n' >&2
  exit 1
fi

if grep -F 'secrets.BASE_PROJECT_TOKEN || github.token' .github/workflows/project-intake.yml >/dev/null; then
  printf 'Project intake workflow must not fall back to github.token for org Project writes.\n' >&2
  exit 1
fi

if ! grep -F 'GH_TOKEN: ${{ secrets.BASE_PROJECT_TOKEN }}' .github/workflows/project-intake.yml >/dev/null; then
  printf 'Project intake workflow must use BASE_PROJECT_TOKEN directly for gh commands.\n' >&2
  exit 1
fi

if ! grep -F 'BASE_PROJECT_MIN_GRAPHQL_REMAINING' .github/workflows/project-intake.yml >/dev/null; then
  printf 'Project intake workflow must define a minimum GraphQL quota before Project mutations.\n' >&2
  exit 1
fi

if ! grep -F 'rateLimit { remaining resetAt }' .github/workflows/project-intake.yml >/dev/null; then
  printf 'Project intake workflow must check GitHub GraphQL quota before Project mutations.\n' >&2
  exit 1
fi

if ! grep -F 'Project intake backfill' CONTRIBUTING.md >/dev/null; then
  printf 'CONTRIBUTING.md must document the throttled Project intake backfill workflow.\n' >&2
  exit 1
fi

if ! grep -F 'gh workflow run project-intake.yml' CONTRIBUTING.md >/dev/null; then
  printf 'CONTRIBUTING.md must include the manual Project intake workflow dispatch command.\n' >&2
  exit 1
fi

fix_comments="$(grep -R -n '# FIX:' lib/bash || true)"
if [[ -n "$fix_comments" ]]; then
  printf 'Production library files must not contain development # FIX: comments:\n%s\n' "$fix_comments" >&2
  exit 1
fi

for command in shellcheck bats; do
  command -v "$command" >/dev/null 2>&1 || {
    printf "Required validation command '%s' was not found.\n" "$command" >&2
    exit 1
  }
done

manifest_source_paths="$(scripts/api-manifest source-paths)" || exit $?
manifest_shellcheck_paths=()
while IFS= read -r file; do
  [[ -n "$file" ]] && manifest_shellcheck_paths+=("$file")
done <<<"$manifest_source_paths"

run_stage "ShellCheck error profile" shellcheck --severity=error \
  bin/base-bash \
  scripts/api-manifest \
  scripts/release \
  scripts/migrate-v2-symbols \
  tests/fixtures/basectl-release-stub \
  tests/bash-42-release-smoke.sh \
  tests/bash-42-logging-smoke.sh \
  tests/bash-option-contract.sh \
  tests/validate.sh \
  tests/lint-warnings.sh \
  examples/std-usage.sh \
  examples/cookbook-cleanup-temp.sh \
  examples/cookbook-args-lists-strings.sh \
  lib/bash/tests/test_helper.sh \
  "${manifest_shellcheck_paths[@]}" \
  tests/release.bats \
  tests/namespace-contract.bats \
  tests/api-manifest.bats

bats_files=(
  tests/release.bats
  tests/namespace-contract.bats
  tests/api-manifest.bats
)
manifest_test_paths="$(scripts/api-manifest test-paths)" || exit $?
while IFS= read -r file; do
  [[ -n "$file" ]] && bats_files+=("$file")
done <<<"$manifest_test_paths"

run_stage "BATS test suites" bats \
  "${bats_files[@]}" || exit $?

run_stage "Bash logging smoke" tests/bash-42-logging-smoke.sh || exit $?
run_stage "Bash release guard smoke" tests/bash-42-release-smoke.sh || exit $?
run_stage "Bash caller-option contract" tests/bash-option-contract.sh || exit $?
run_stage "examples/std-usage.sh" examples/std-usage.sh >/dev/null || exit $?
run_stage "examples/cookbook-cleanup-temp.sh" examples/cookbook-cleanup-temp.sh >/dev/null || exit $?
run_stage "examples/cookbook-args-lists-strings.sh" examples/cookbook-args-lists-strings.sh >/dev/null || exit $?

printf 'Bash library validation passed.\n'
