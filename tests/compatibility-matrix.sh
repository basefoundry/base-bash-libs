#!/usr/bin/env bash

# Fast, networkless compatibility probe. It reports unavailable optional
# runtimes as skips and fails only for a runtime that is present but violates
# the source/module contract.

matrix_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
matrix_repo_root="$(cd -- "$matrix_script_dir/.." && pwd -P)" || exit 1

matrix_fail() {
    printf 'Compatibility matrix failed: %s\n' "$*" >&2
    exit 1
}

matrix_bash_files=()
while IFS= read -r matrix_file; do
    [[ -n "$matrix_file" ]] && matrix_bash_files+=("$matrix_file")
done < <(find "$matrix_repo_root/lib" "$matrix_repo_root/bin" "$matrix_repo_root/scripts" -type f \( -name '*.sh' -o -name 'base-bash' -o -name 'library-bundle' -o -name 'vendor' \) -print | sort)

matrix_probe_bash() {
    local matrix_bash="$1"
    local matrix_file

    [[ -x "$matrix_bash" ]] || matrix_fail "Bash runtime is not executable: $matrix_bash"
    for matrix_file in "${matrix_bash_files[@]}"; do
        "$matrix_bash" -n "$matrix_file" || matrix_fail "$matrix_bash failed syntax check for $matrix_file"
    done
    "$matrix_bash" "$matrix_repo_root/tests/bash-option-contract.sh" >/dev/null 2>&1 ||
        matrix_fail "$matrix_bash failed the option contract"
    printf 'PASS bash=%s version=%s\n' "$matrix_bash" "$($matrix_bash --version | sed -n '1p')"
}

matrix_probe_bash "${BASH:-bash}"

for matrix_candidate in /usr/local/bin/bash /opt/homebrew/bin/bash /bin/bash; do
    [[ -x "$matrix_candidate" ]] || continue
    [[ "$matrix_candidate" == "${BASH:-}" ]] && continue
    matrix_probe_bash "$matrix_candidate"
done

if [[ "${1:-}" == --container ]]; then
    [[ "${2:-}" == alpine ]] || matrix_fail "usage: $0 [--container alpine]"
    if ! command -v docker >/dev/null 2>&1; then
        printf 'SKIP container=alpine reason=docker-unavailable\n'
        exit 0
    fi
    docker run --rm --network none --read-only --cap-drop ALL \
        --tmpfs /tmp:rw,noexec,nosuid,nodev,size=16m,mode=1777 \
        --mount "type=bind,src=$matrix_repo_root,dst=/workspace,readonly" \
        --workdir /workspace alpine:3.20 sh -c 'apk add --no-cache bash >/dev/null && bash tests/bash-option-contract.sh'
    printf 'PASS container=alpine\n'
fi
