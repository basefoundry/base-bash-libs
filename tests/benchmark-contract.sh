#!/usr/bin/env bash

# Validate the machine-readable benchmark contract without making a network
# request or relying on a package manager. Timing values are evidence, not a
# performance claim; this gate checks that the evidence remains reproducible.

benchmark_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
benchmark_repo_root="$(cd -- "$benchmark_script_dir/.." && pwd -P)" || exit 1
benchmark_tmp="$(mktemp -d "${TMPDIR:-/tmp}/base-bash-benchmark-contract.XXXXXX")" || exit 1

benchmark_cleanup() {
    rm -rf -- "$benchmark_tmp"
}
trap benchmark_cleanup EXIT

benchmark_fail() {
    printf 'Benchmark contract failed: %s\n' "$*" >&2
    if [[ -f "$benchmark_tmp/output" ]]; then
        sed 's/^/  /' "$benchmark_tmp/output" >&2
    fi
    exit 1
}

BASE_REFERENCE_BENCHMARK_ITERATIONS=2 \
    "$benchmark_repo_root/benchmarks/reference-apps.sh" >"$benchmark_tmp/output" 2>&1 ||
    benchmark_fail 'reference benchmark runner returned a failure'

grep -Fx 'benchmark_schema=1' "$benchmark_tmp/output" >/dev/null ||
    benchmark_fail 'schema marker is missing'
grep -Fx 'iterations=2' "$benchmark_tmp/output" >/dev/null ||
    benchmark_fail 'iteration marker is missing or incorrect'
grep -F 'bash=' "$benchmark_tmp/output" >/dev/null || benchmark_fail 'Bash provenance is missing'
grep -F 'os=' "$benchmark_tmp/output" >/dev/null || benchmark_fail 'OS provenance is missing'
grep -F 'cpu_arch=' "$benchmark_tmp/output" >/dev/null || benchmark_fail 'CPU architecture provenance is missing'
grep -E '^framework_commit=([[:xdigit:]]{40}|unknown)$' "$benchmark_tmp/output" >/dev/null ||
    benchmark_fail 'framework commit provenance is malformed'
grep -E '^framework_dirty_state=(clean|dirty|unknown)$' "$benchmark_tmp/output" >/dev/null ||
    benchmark_fail 'framework dirty-state provenance is malformed'
grep -E '^timer_source=(date \+%s%N|date \+%s)$' "$benchmark_tmp/output" >/dev/null ||
    benchmark_fail 'timer source is missing'
grep -E '^timer_resolution_ns=[1-9][0-9]*$' "$benchmark_tmp/output" >/dev/null ||
    benchmark_fail 'timer resolution is missing'
grep -E '^timer_precision=(nanoseconds|seconds)$' "$benchmark_tmp/output" >/dev/null ||
    benchmark_fail 'timer precision is missing'
grep -E '^benchmark_quality=(sufficient|insufficient-precision)$' "$benchmark_tmp/output" >/dev/null ||
    benchmark_fail 'benchmark quality is missing'
grep -E '^budget_startup_help_avg_ns=[1-9][0-9]*$' "$benchmark_tmp/output" >/dev/null ||
    benchmark_fail 'performance budget is missing'
grep -E '^budget_status=(pass|exceeded|not-assessed)$' "$benchmark_tmp/output" >/dev/null ||
    benchmark_fail 'performance budget result is missing'
grep -Fx 'Methodology: fresh-process plain Bash, std source, cli import, and process startup plus --help through the repository launcher;' \
    "$benchmark_tmp/output" >/dev/null || benchmark_fail 'methodology line is missing'
grep -F 'stage=plain-bash' "$benchmark_tmp/output" >/dev/null || benchmark_fail 'plain Bash baseline is missing'
grep -F 'stage=std-source' "$benchmark_tmp/output" >/dev/null || benchmark_fail 'stdlib baseline is missing'
grep -F 'stage=cli-import' "$benchmark_tmp/output" >/dev/null || benchmark_fail 'CLI import baseline is missing'

declare -A benchmark_seen=()
benchmark_record_count=0
while IFS=$'\t' read -r benchmark_app_field benchmark_total_field benchmark_average_field; do
    [[ "$benchmark_app_field" == app=* ]] || continue
    benchmark_app="${benchmark_app_field#app=}"
    benchmark_total="${benchmark_total_field#startup_help_total_ns=}"
    benchmark_average="${benchmark_average_field#startup_help_avg_ns=}"
    case "$benchmark_app" in
        installer|release-helper|ops-cli) ;;
        *) benchmark_fail "unexpected application record '$benchmark_app'" ;;
    esac
    [[ -z "${benchmark_seen[$benchmark_app]+set}" ]] ||
        benchmark_fail "duplicate application record '$benchmark_app'"
    [[ "$benchmark_total" =~ ^[0-9]+$ && "$benchmark_average" =~ ^[0-9]+$ ]] ||
        benchmark_fail "non-numeric timing for '$benchmark_app'"
    ((benchmark_total >= benchmark_average)) ||
        benchmark_fail "average timing exceeds total for '$benchmark_app'"
    benchmark_seen["$benchmark_app"]=1
    benchmark_record_count=$((benchmark_record_count + 1))
done < "$benchmark_tmp/output"

[[ "$benchmark_record_count" == 3 ]] ||
    benchmark_fail "expected three application records, found $benchmark_record_count"
for benchmark_app in installer release-helper ops-cli; do
    [[ -n "${benchmark_seen[$benchmark_app]+set}" ]] ||
        benchmark_fail "missing application record '$benchmark_app'"
done

benchmark_lowres_shim="$benchmark_tmp/lowres-bin"
mkdir -p "$benchmark_lowres_shim"
cat > "$benchmark_lowres_shim/date" <<'EOF'
#!/usr/bin/env bash
case "${1-}" in
+%s%N|+%s) printf '1\n' ;;
*) exit 2 ;;
esac
EOF
chmod +x "$benchmark_lowres_shim/date"
PATH="$benchmark_lowres_shim:$PATH" BASE_REFERENCE_BENCHMARK_ITERATIONS=1 \
    "$benchmark_repo_root/benchmarks/reference-apps.sh" >"$benchmark_tmp/lowres-output" 2>&1 ||
    benchmark_fail 'low-resolution timer fixture returned a failure'
grep -Fx 'timer_precision=seconds' "$benchmark_tmp/lowres-output" >/dev/null ||
    benchmark_fail 'low-resolution fixture did not disclose seconds precision'
grep -Fx 'benchmark_quality=insufficient-precision' "$benchmark_tmp/lowres-output" >/dev/null ||
    benchmark_fail 'low-resolution fixture was treated as precise'
grep -Fx 'budget_status=not-assessed' "$benchmark_tmp/lowres-output" >/dev/null ||
    benchmark_fail 'low-resolution fixture incorrectly evaluated the budget'

printf 'Benchmark contract passed: apps=3 iterations=2.\n'
