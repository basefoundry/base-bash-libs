#!/usr/bin/env bash

contract_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
contract_workflow="$contract_root/.github/workflows/tests.yml"
contract_pin="90c0efbd980766027ff38f2d2ff6be4c96bbee97"

contract_fail() {
    printf 'Downstream demo contract failed: %s\n' "$*" >&2
    exit 1
}

grep -Fq 'https://github.com/basefoundry/base-bash-libs-demo' \
    "$contract_root/README.md" || contract_fail "README link is missing"
grep -Fq '| Base Bash Demo |' "$contract_root/docs/consumer-validation-status.md" || \
    contract_fail "consumer ledger entry is missing"
grep -Fq 'repository: basefoundry/base-bash-libs-demo' "$contract_workflow" || \
    contract_fail "workflow repository is missing"
grep -Fq "ref: $contract_pin" "$contract_workflow" || \
    contract_fail "workflow must pin the reviewed demo commit"
grep -Fq '.downstream/base-bash-libs-demo/tests/candidate-smoke.sh' \
    "$contract_workflow" || contract_fail "candidate smoke invocation is missing"

printf 'Downstream demo contract passed at %s.\n' "$contract_pin"
