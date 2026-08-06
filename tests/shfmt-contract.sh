#!/usr/bin/env bash

# Formatting is a required CI check, but shfmt remains a CI tool rather than
# a runtime dependency. The workflow supplies the pinned shfmt container;
# local callers can install shfmt and run this same contract.

shfmt_repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
cd "$shfmt_repo_root" || exit 1

command -v shfmt > /dev/null 2>&1 || {
    printf 'shfmt is required for this contract; install it or use the pinned CI image.\n' >&2
    exit 127
}

shfmt_files=()
while IFS= read -r shfmt_file; do
    case "$shfmt_file" in
    *.sh | *.bash | bin/base-bash | scripts/api-manifest | scripts/first-party-cutover | scripts/library-bundle | scripts/migrate-v2-symbols | scripts/release | scripts/vendor | tests/fixtures/basectl-release-stub)
        shfmt_files+=("$shfmt_file")
        ;;
    esac
done < <(git ls-files)

((${#shfmt_files[@]} > 0)) || {
    printf 'shfmt contract failed: no Bash sources were found.\n' >&2
    exit 1
}

shfmt -d -ln bash -i 4 -sr "${shfmt_files[@]}"
