#!/usr/bin/env bash

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
launcher="$repo_root/bin/base-bash"
framework="$repo_root/lib/bash"
iterations="${BASE_REFERENCE_BENCHMARK_ITERATIONS:-10}"

[[ "$iterations" =~ ^[1-9][0-9]*$ ]] || { printf 'iterations must be positive\n' >&2; exit 2; }

printf 'benchmark_schema=1\n'
printf 'bash=%s\n' "$BASH_VERSION"
printf 'os=%s\n' "$(uname -s)"
printf 'iterations=%s\n' "$iterations"
printf 'framework_commit=%s\n' "$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || printf unknown)"

for app in installer release-helper ops-cli; do
    start_ns="$(date +%s%N 2>/dev/null || date +%s000000000)"
    for ((index = 0; index < iterations; index++)); do
        BASE_BASH_LIBS_DIR="$framework" "$launcher" \
            "$repo_root/examples/reference-apps/$app/bin/app" --help >/dev/null || exit $?
    done
    end_ns="$(date +%s%N 2>/dev/null || date +%s000000000)"
    elapsed_ns=$((end_ns - start_ns))
    printf 'app=%s\tstartup_help_total_ns=%s\tstartup_help_avg_ns=%s\n' \
        "$app" "$elapsed_ns" "$((elapsed_ns / iterations))"
done

printf '%s\n' 'Methodology: process startup plus --help through the repository launcher;'
printf '%s\n' 'no network, filesystem mutation, or warm-process claims are included.'
