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
done
grep -F '[[ "$VALIDATE_RESULT" == success ]]' "$tests_workflow" > /dev/null ||
    contract_fail 'product aggregate must require success, not merely completion'
grep -F '[[ "$DOWNSTREAM_DEMO_RESULT" == success ]]' "$tests_workflow" > /dev/null ||
    contract_fail 'downstream demo must be part of the product aggregate'

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
