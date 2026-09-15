#!/usr/bin/env bash

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
cd "$repo_root" || exit 1

for file in CODE_OF_CONDUCT.md ROADMAP.md docs/community.md docs/who-uses-base-bash.md \
    docs/independent-validation.md docs/consumer-validation-status.md \
    .github/ISSUE_TEMPLATE/bug.yml \
    .github/ISSUE_TEMPLATE/feature.yml .github/ISSUE_TEMPLATE/documentation.yml \
    .github/ISSUE_TEMPLATE/config.yml; do
    [[ -f "$file" ]] || {
        printf 'Missing community artifact: %s\n' "$file" >&2
        exit 1
    }
done

grep -F 'SECURITY.md' docs/community.md > /dev/null || exit 1
grep -F 'https://github.com/basefoundry/base-bash-libs/discussions' docs/community.md > /dev/null || exit 1
grep -F 'https://github.com/basefoundry/base-bash-libs/discussions' README.md > /dev/null || exit 1
if grep -F 'when enabled for the repository' docs/community.md > /dev/null; then
    printf 'Community contract still hedges the Discussions channel.\n' >&2
    exit 1
fi
grep -F 'No public entries yet.' docs/who-uses-base-bash.md > /dev/null || exit 1
grep -F 'public fork' CONTRIBUTING.md > /dev/null || exit 1
grep -F 'small-fix/<YYYYMMDD>-<slug>' ROADMAP.md CONTRIBUTING.md docs/community.md \
    .github/pull_request_template.md > /dev/null || exit 1
grep -F '      - labeled' .github/workflows/issue-branch-policy.yml > /dev/null || exit 1
grep -F '      - unlabeled' .github/workflows/issue-branch-policy.yml > /dev/null || exit 1

issue_branch_pattern="$(sed -n \
    "s/^[[:space:]]*issue_branch_pattern='\\([^']*\\)'[[:space:]]*$/\\1/p" \
    .github/workflows/issue-branch-policy.yml)"
small_fix_branch_pattern="$(sed -n \
    "s/^[[:space:]]*small_fix_branch_pattern='\\([^']*\\)'[[:space:]]*$/\\1/p" \
    .github/workflows/issue-branch-policy.yml)"
[[ -n "$issue_branch_pattern" && -n "$small_fix_branch_pattern" ]] || {
    printf 'Branch policy patterns are missing.\n' >&2
    exit 1
}
[[ "ci/498-20260915-policy-fix" =~ $issue_branch_pattern ]] || exit 1
[[ "small-fix/20260915-policy-docs" =~ $small_fix_branch_pattern ]] || exit 1
[[ ! "small-fix/20260915" =~ $small_fix_branch_pattern ]] || exit 1
[[ ! "small-fix/20260915/extra" =~ $small_fix_branch_pattern ]] || exit 1

printf 'Community contract passed; no independent users are claimed yet.\n'
