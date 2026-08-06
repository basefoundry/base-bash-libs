#!/usr/bin/env bash

# Repository-local assertions for the hosted quality workflow. Tool execution
# happens in the pinned CI containers; this contract prevents the workflow
# from silently losing its required checks, isolation, or immutable inputs.

quality_repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
cd "$quality_repo_root" || exit 1

quality_fail() {
    printf 'Quality contract failed: %s\n' "$*" >&2
    exit 1
}

quality_workflow=".github/workflows/quality.yml"
[[ -f "$quality_workflow" ]] || quality_fail "missing $quality_workflow"

grep -F 'permissions:' "$quality_workflow" > /dev/null || quality_fail 'quality workflow must declare permissions'
grep -F 'contents: read' "$quality_workflow" > /dev/null || quality_fail 'quality workflow must be read-only'
grep -F 'mvdan/shfmt@sha256:' "$quality_workflow" > /dev/null || quality_fail 'shfmt image must be digest-pinned'
grep -F 'rhysd/actionlint@sha256:' "$quality_workflow" > /dev/null || quality_fail 'actionlint image must be digest-pinned'
grep -F -- '--network none' "$quality_workflow" > /dev/null || quality_fail 'quality containers must be networkless'
grep -F -- '--read-only' "$quality_workflow" > /dev/null || quality_fail 'quality containers must be read-only'
grep -F 'tests/lint-warnings.sh' "$quality_workflow" > /dev/null || quality_fail 'warning ShellCheck gate is missing'
grep -F -- '-d -ln bash' "$quality_workflow" > /dev/null || quality_fail 'shfmt contract gate is missing'
grep -F 'tests/quality-contract.sh' "$quality_workflow" > /dev/null || quality_fail 'quality contract gate is missing'
grep -F 'git diff --name-only' "$quality_workflow" > /dev/null || quality_fail 'shfmt gate must inspect changed sources'

workflow_action_count=0
while IFS= read -r action_ref; do
    [[ -n "$action_ref" ]] || continue
    [[ "$action_ref" =~ @[0-9a-f]{40}([[:space:]]|$) ]] ||
        quality_fail "workflow action is not pinned: $action_ref"
    workflow_action_count=$((workflow_action_count + 1))
done < <(grep -E '^[[:space:]]*-[[:space:]]*uses:[[:space:]]*[^#]+' .github/workflows/*.yml || true)
((workflow_action_count > 0)) || quality_fail 'no pinned workflow actions were found'

grep -F 'concurrency:' .github/workflows/tests.yml > /dev/null ||
    quality_fail 'tests workflow must cancel superseded runs'
grep -F 'concurrency:' .github/workflows/quality.yml > /dev/null ||
    quality_fail 'quality workflow must cancel superseded runs'

printf 'Quality contract passed: pinned-actions=%s.\n' "$workflow_action_count"
