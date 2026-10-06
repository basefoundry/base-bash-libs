#!/usr/bin/env bash

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
tests_workflow="$repo_root/.github/workflows/tests.yml"
quality_workflow="$repo_root/.github/workflows/quality.yml"

contract_fail() {
    printf 'CI policy contract failed: %s\n' "$*" >&2
    exit 1
}

for file in "$tests_workflow" "$quality_workflow"; do
    [[ -f "$file" ]] || contract_fail "missing workflow: $file"
done

grep -F '  product-validation:' "$tests_workflow" > /dev/null ||
    contract_fail 'product validation aggregate job is missing'
grep -F '    name: Product validation' "$tests_workflow" > /dev/null ||
    contract_fail 'product validation context name is unstable or missing'
grep -F '    if: ${{ always() }}' "$tests_workflow" > /dev/null ||
    contract_fail 'product validation must run after skipped or failed dependencies'
grep -F '    needs: [validate, bash-42-logging, representative-bash, release-gates, downstream-demo]' \
    "$tests_workflow" > /dev/null ||
    contract_fail 'product validation must cover every product lane'
for result_name in VALIDATE_RESULT BASH_42_RESULT REPRESENTATIVE_BASH_RESULT RELEASE_GATES_RESULT DOWNSTREAM_DEMO_RESULT; do
    grep -F "          $result_name:" "$tests_workflow" > /dev/null ||
        contract_fail "product result is not wired: $result_name"
    grep -F "[[ \"\$$result_name\" == success ]]" "$tests_workflow" > /dev/null ||
        contract_fail "product result is not required to succeed: $result_name"
done

product_needs_line="$(
    awk '
        /^  product-validation:/ { in_product = 1; next }
        in_product && /^  [A-Za-z0-9_-]+:/ { exit }
        in_product && /needs:/ { print; exit }
    ' "$tests_workflow"
)"
[[ -n "$product_needs_line" ]] ||
    contract_fail 'product validation needs list is missing'
while IFS= read -r job_id; do
    [[ "$job_id" == product-validation ]] && continue
    awk -v expected_job="$job_id" '
        {
            for (i = 1; i <= NF; i++) {
                token = $i
                gsub(/[\[\],]/, "", token)
                if (token == expected_job) {
                    found = 1
                }
            }
        }
        END { exit !found }
    ' <<< "$product_needs_line" ||
        contract_fail "product validation does not cover job: $job_id"
done < <(
    awk '
        /^jobs:/ { in_jobs = 1; next }
        in_jobs && /^  [A-Za-z0-9_-]+:/ {
            job_id = $1
            sub(/:$/, "", job_id)
            print job_id
        }
    ' "$tests_workflow"
)

grep -F '  quality-contract:' "$quality_workflow" > /dev/null ||
    contract_fail 'quality aggregate job is missing'
grep -F '    name: Quality contract' "$quality_workflow" > /dev/null ||
    contract_fail 'quality context name is unstable or missing'
grep -F '    if: ${{ always() }}' "$quality_workflow" > /dev/null ||
    contract_fail 'quality aggregate must run after a skipped or failed dependency'
grep -F '    needs: [quality]' "$quality_workflow" > /dev/null ||
    contract_fail 'quality aggregate must depend on the quality lane'
grep -F '          QUALITY_RESULT: ${{ needs.quality.result }}' "$quality_workflow" > /dev/null ||
    contract_fail 'quality result is not wired into the aggregate'
grep -F 'if [[ "$QUALITY_RESULT" != success ]]' "$quality_workflow" > /dev/null ||
    contract_fail 'quality aggregate must require success, not merely completion'

printf 'CI policy contract passed: product and quality aggregates are explicit and fail closed.\n'
