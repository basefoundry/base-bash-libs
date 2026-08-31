#!/usr/bin/env bash

# Exercise import, temporary-directory, cleanup, and launcher boundaries in
# parallel processes. The contract is deliberately deterministic and
# networkless; it catches shared-state regressions without making a timing
# claim about a particular machine.

concurrency_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
concurrency_repo_root="$(cd -- "$concurrency_script_dir/.." && pwd -P)" || exit 1
concurrency_tmp="$(mktemp -d "${TMPDIR:-/tmp}/base-bash-concurrency-contract.XXXXXX")" || exit 1
concurrency_status=0

concurrency_cleanup() {
    rm -rf -- "$concurrency_tmp"
}
trap concurrency_cleanup EXIT

concurrency_fail() {
    printf 'Concurrency contract failed: %s\n' "$*" >&2
    concurrency_status=1
}

concurrency_worker() {
    local worker_id="$1"
    local worker_dir output expected attempt
    trap - EXIT
    # shellcheck disable=SC2034 # base_init publishes into this caller-owned array by name.
    local -a init_args=()

    export BASE_BASH_LIBS_DIR="$concurrency_repo_root/lib/bash"
    # shellcheck source=../lib/bash/std/lib_std.sh
    source "$concurrency_repo_root/lib/bash/std/lib_std.sh" || return 1
    base_init init_args --source "$concurrency_script_dir/concurrency-contract.sh" -- || return 1
    base_std_make_temp_dir worker_dir "concurrency-$worker_id" || return 1
    base_std_import str/lib_str.sh || return 1
    output="  worker-$worker_id  "
    base_str_trim output || return 1
    expected="worker-$worker_id"
    [[ "$output" == "$expected" ]] || return 1
    [[ -d "$worker_dir" ]] || return 1
    # Repeated short-lived supervised commands stress Bash's process-group
    # setup while every worker is active. The watchdog must never become a
    # second job-control race for commands that finish immediately.
    for ((attempt = 1; attempt <= 4; attempt += 1)); do
        base_std_run --no-exit --quiet --timeout 5 true || return $?
    done
    # Async function subshells do not consistently deliver inherited EXIT
    # traps on every supported Bash release. Invoke the shared dispatcher
    # explicitly so the cleanup assertion remains portable and deterministic.
    __base_bash_libs_std_run_cleanup_hooks__ || return $?
    [[ ! -e "$worker_dir" ]] || return 1
    printf '%s\n' "$worker_dir"
}

concurrency_workers=()
concurrency_logs=()
concurrency_worker_count=16
for ((concurrency_index = 1; concurrency_index <= concurrency_worker_count; concurrency_index += 1)); do
    concurrency_log="$concurrency_tmp/worker-$concurrency_index.log"
    concurrency_logs+=("$concurrency_log")
    concurrency_worker "$concurrency_index" > "$concurrency_log" 2>&1 &
    concurrency_workers+=("$!")
done

for concurrency_index in "${!concurrency_workers[@]}"; do
    if ! wait "${concurrency_workers[$concurrency_index]}"; then
        concurrency_fail "worker $((concurrency_index + 1)) returned a failure"
        sed 's/^/  /' "${concurrency_logs[$concurrency_index]}" >&2
    fi
done

concurrency_seen="$concurrency_tmp/seen"
: > "$concurrency_seen" || concurrency_fail 'could not create result ledger'
for concurrency_log in "${concurrency_logs[@]}"; do
    concurrency_worker_dir="$(tail -n 1 "$concurrency_log" 2> /dev/null || true)"
    [[ -n "$concurrency_worker_dir" ]] || {
        concurrency_fail "worker did not publish a managed directory: $concurrency_log"
        continue
    }
    [[ ! -e "$concurrency_worker_dir" ]] ||
        concurrency_fail "worker directory was not cleaned up: $concurrency_worker_dir"
    printf '%s\n' "$concurrency_worker_dir" >> "$concurrency_seen"
done

concurrency_result_count="$(wc -l < "$concurrency_seen" | tr -d ' ')"
[[ "$concurrency_result_count" == "$concurrency_worker_count" ]] ||
    concurrency_fail "expected $concurrency_worker_count worker results, found $concurrency_result_count"

concurrency_unique_count="$(sort -u "$concurrency_seen" | wc -l | tr -d ' ')"
[[ "$concurrency_unique_count" == "$concurrency_worker_count" ]] ||
    concurrency_fail 'parallel workers received duplicate temporary directories'

if ((concurrency_status != 0)); then
    exit "$concurrency_status"
fi

printf 'Concurrency contract passed: workers=%s unique-temp-dirs=%s.\n' \
    "$concurrency_worker_count" "$concurrency_unique_count"
