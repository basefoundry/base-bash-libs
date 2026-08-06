#!/usr/bin/env bash

# Exercise the caller-option contract through every local distribution shape.
# The test intentionally uses only repository-local, verified inputs so release
# validation cannot silently pass because a package manager or network happened
# to be available.

artifact_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
artifact_repo_root="$(cd -- "$artifact_script_dir/.." && pwd -P)" || exit 1
artifact_tmp="$(mktemp -d "${TMPDIR:-/tmp}/base-bash-artifact-contract.XXXXXX")" || exit 1

artifact_cleanup() {
    rm -rf -- "$artifact_tmp"
}
trap artifact_cleanup EXIT

artifact_fail() {
    printf 'Artifact contract failed: %s\n' "$*" >&2
    exit 1
}

artifact_copy_contract() {
    local root="$1"
    [[ "$root" == "$artifact_repo_root" ]] && return 0
    mkdir -p "$root/tests" || artifact_fail "could not create test directory for $root"
    cp -- "$artifact_repo_root/tests/bash-option-contract.sh" \
        "$root/tests/bash-option-contract.sh" || artifact_fail "could not copy option contract to $root"
    chmod +x "$root/tests/bash-option-contract.sh" || artifact_fail "could not make option contract executable"
}

artifact_run_contract() {
    local label="$1" root="$2" mode status index
    local -a modes=(none e u p eu ep up eup) pids=() logs=()
    artifact_copy_contract "$root"
    # These modes are independent processes. Running them concurrently keeps
    # the artifact gate practical even on slower hosted runners while each
    # mode still receives an isolated temporary state and timeout budget.
    for mode in "${modes[@]}"; do
        logs+=("$artifact_tmp/${label}-${mode}.log")
        "$BASH" "$root/tests/bash-option-contract.sh" --mode "$mode" \
            >"${logs[${#logs[@]} - 1]}" 2>&1 &
        pids+=("$!")
    done
    for index in "${!modes[@]}"; do
        if wait "${pids[$index]}"; then
            status=0
        else
            status=$?
        fi
        if [[ "$status" != 0 ]]; then
            cat "${logs[$index]}" >&2
            artifact_fail "$label option mode ${modes[$index]} returned $status"
        fi
    done
    printf 'PASS artifact=%s option-modes=8\n' "$label"
}

artifact_bundle="$artifact_tmp/bundle"
artifact_vendor="$artifact_tmp/vendor"
artifact_standalone="$artifact_tmp/standalone"
artifact_project="$artifact_tmp/project"

"$artifact_repo_root/scripts/library-bundle" bundle "$artifact_bundle" >/dev/null ||
    artifact_fail 'deterministic bundle creation failed'
"$artifact_repo_root/scripts/library-bundle" verify "$artifact_bundle" >/dev/null ||
    artifact_fail 'deterministic bundle verification failed'
"$artifact_repo_root/scripts/vendor" create "$artifact_bundle" "$artifact_vendor" >/dev/null ||
    artifact_fail 'verified vendor creation failed'

artifact_run_contract source-checkout "$artifact_repo_root"
artifact_run_contract generated-bundle "$artifact_bundle"
artifact_run_contract vendored-tree "$artifact_vendor"

mkdir -p "$artifact_project" || artifact_fail 'could not create generated project directory'
BASE_BASH_LIBS_DIR="$artifact_repo_root/lib/bash" \
    "$artifact_repo_root/bin/base-bash" init --profile standard --dir "$artifact_project" >/dev/null ||
    artifact_fail 'standard project generation failed'

PATH="$artifact_repo_root/bin:$PATH" BASE_BASH_LIBS_DIR="$artifact_repo_root/lib/bash" \
    "$artifact_project/bin/app" --help >/dev/null || artifact_fail 'generated app help failed'
PATH="$artifact_repo_root/bin:$PATH" BASE_BASH_LIBS_DIR="$artifact_repo_root/lib/bash" \
    "$artifact_project/bin/app" run --dry-run >/dev/null || artifact_fail 'generated app dry-run failed'

"$artifact_repo_root/scripts/vendor" standalone "$artifact_project" "$artifact_bundle" \
    "$artifact_standalone" >/dev/null || artifact_fail 'standalone bundle creation failed'
artifact_run_contract standalone-bundle "$artifact_standalone"

printf 'Artifact contract passed for source, generated, vendored, standalone, and project-kit paths.\n'
