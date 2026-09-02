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
grep -F 'base-bash init --profile standard --dir demo' docs/v2/quickstart.md > /dev/null || {
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

printf 'Documentation contract passed.\n'
