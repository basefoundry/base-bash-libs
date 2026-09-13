#!/usr/bin/env bash

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
launcher="$repo_root/bin/base-bash"
framework="$repo_root/lib/bash"
iterations="${BASE_REFERENCE_BENCHMARK_ITERATIONS:-10}"
budget_ns="${BASE_REFERENCE_BENCHMARK_BUDGET_NS:-1000000000}"

[[ "$iterations" =~ ^[1-9][0-9]*$ ]] || {
    printf 'iterations must be positive\n' >&2
    exit 2
}
[[ "$budget_ns" =~ ^[1-9][0-9]*$ ]] || {
    printf 'budget must be a positive number of nanoseconds\n' >&2
    exit 2
}

benchmark_timestamp_ns() {
    local timestamp

    timestamp="$(date +%s%N 2> /dev/null || true)"
    if [[ "$timestamp" =~ ^[0-9]{18,}$ ]]; then
        benchmark_timer_source='date +%s%N'
        benchmark_timer_resolution_ns=1
        benchmark_timer_precision=nanoseconds
        benchmark_timer_high_resolution=1
        printf '%s\n' "$timestamp"
        return 0
    fi

    timestamp="$(date +%s 2> /dev/null)" || return 1
    [[ "$timestamp" =~ ^[0-9]+$ ]] || return 1
    benchmark_timer_source='date +%s'
    benchmark_timer_resolution_ns=1000000000
    benchmark_timer_precision=seconds
    benchmark_timer_high_resolution=0
    printf '%s000000000\n' "$timestamp"
}

benchmark_measure_stage() {
    local label="$1" start_ns end_ns elapsed_ns average_ns index
    shift
    start_ns="$(benchmark_timestamp_ns)" || return 1
    for ((index = 0; index < iterations; index++)); do
        "$@" > /dev/null || return $?
    done
    end_ns="$(benchmark_timestamp_ns)" || return 1
    elapsed_ns=$((end_ns - start_ns))
    ((elapsed_ns >= 0)) || elapsed_ns=0
    average_ns=$((elapsed_ns / iterations))
    printf 'stage=%s\tstage_total_ns=%s\tstage_avg_ns=%s\n' \
        "$label" "$elapsed_ns" "$average_ns"
}

benchmark_run_app() {
    local app="$1"
    BASE_BASH_LIBS_DIR="$framework" "$launcher" \
        "$repo_root/examples/reference-apps/$app/bin/app" --help
}

benchmark_max_app_avg_ns=0

benchmark_framework_commit="$(git -C "$repo_root" rev-parse HEAD 2> /dev/null || printf unknown)"
benchmark_dirty_state='unknown'
if [[ "$benchmark_framework_commit" != unknown ]]; then
    if [[ -n "$(git -C "$repo_root" status --porcelain 2> /dev/null)" ]]; then
        benchmark_dirty_state=dirty
    else
        benchmark_dirty_state=clean
    fi
fi
benchmark_timer_source=unknown
benchmark_timer_resolution_ns=0
benchmark_timer_precision=unknown
benchmark_timer_high_resolution=0
benchmark_timestamp_ns > /dev/null || exit 1
if ((benchmark_timer_high_resolution)); then
    benchmark_quality=sufficient
else
    benchmark_quality=insufficient-precision
fi

printf 'benchmark_schema=1\n'
printf 'bash=%s\n' "$BASH_VERSION"
printf 'os=%s\n' "$(uname -s)"
printf 'cpu_arch=%s\n' "$(uname -m)"
printf 'iterations=%s\n' "$iterations"
printf 'framework_commit=%s\n' "$benchmark_framework_commit"
printf 'framework_dirty_state=%s\n' "$benchmark_dirty_state"
printf 'timer_source=%s\n' "$benchmark_timer_source"
printf 'timer_resolution_ns=%s\n' "$benchmark_timer_resolution_ns"
printf 'timer_precision=%s\n' "$benchmark_timer_precision"
printf 'benchmark_quality=%s\n' "$benchmark_quality"
printf 'budget_startup_help_avg_ns=%s\n' "$budget_ns"

benchmark_measure_stage plain-bash bash -c ':' || exit $?
benchmark_measure_stage std-source env BASE_BASH_LIBS_DIR="$framework" bash -c \
    'source "$1/std/lib_std.sh"' bash "$framework" || exit $?
benchmark_measure_stage cli-import env BASE_BASH_LIBS_DIR="$framework" bash -c \
    'source "$1/std/lib_std.sh"; base_std_import cli/lib_cli.sh' bash "$framework" || exit $?

for app in installer release-helper ops-cli; do
    start_ns="$(benchmark_timestamp_ns)" || exit 1
    for ((index = 0; index < iterations; index++)); do
        benchmark_run_app "$app" > /dev/null || exit $?
    done
    end_ns="$(benchmark_timestamp_ns)" || exit 1
    elapsed_ns=$((end_ns - start_ns))
    ((elapsed_ns >= 0)) || elapsed_ns=0
    average_ns=$((elapsed_ns / iterations))
    ((average_ns > benchmark_max_app_avg_ns)) && benchmark_max_app_avg_ns=$average_ns
    printf 'app=%s\tstartup_help_total_ns=%s\tstartup_help_avg_ns=%s\n' \
        "$app" "$elapsed_ns" "$average_ns"
done

if ((benchmark_timer_high_resolution)); then
    if ((benchmark_max_app_avg_ns <= budget_ns)); then
        printf 'budget_status=pass\n'
    else
        printf 'budget_status=exceeded\n'
    fi
else
    printf 'budget_status=not-assessed\n'
fi

printf '%s\n' 'Methodology: fresh-process plain Bash, std source, cli import, and process startup plus --help through the repository launcher;'
printf '%s\n' 'no network, filesystem mutation, or warm-process claims are included; compare only matching provenance and timer precision.'
