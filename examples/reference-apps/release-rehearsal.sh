#!/usr/bin/env bash

# Rehearse an immutable v2 deployment and a rollback without network access.
# The caller supplies unpacked, independently verified framework directories.

rehearsal_repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)" || exit 1
rehearsal_launcher="$rehearsal_repo_root/bin/base-bash"
rehearsal_report=""
rehearsal_candidate=""
rehearsal_rollback=""

rehearsal_usage() {
    cat >&2 << 'EOF'
Usage: examples/reference-apps/release-rehearsal.sh \
  --candidate FRAMEWORK_DIR --rollback FRAMEWORK_DIR [--report FILE]

FRAMEWORK_DIR must be an unpacked, independently verified v2 framework root
containing lib/bash/base-bash-libs.release. The candidate is exercised first;
the rollback directory is then exercised as the previous immutable target.
EOF
}

rehearsal_fail() {
    printf 'Reference release rehearsal failed: %s\n' "$*" >&2
    exit 1
}

while (($#)); do
    case "$1" in
    --candidate)
        [[ -n "${2-}" ]] || rehearsal_fail '--candidate requires a directory'
        rehearsal_candidate="$2"
        shift
        ;;
    --rollback)
        [[ -n "${2-}" ]] || rehearsal_fail '--rollback requires a directory'
        rehearsal_rollback="$2"
        shift
        ;;
    --report)
        [[ -n "${2-}" ]] || rehearsal_fail '--report requires a file'
        rehearsal_report="$2"
        shift
        ;;
    -h | --help)
        rehearsal_usage
        exit 0
        ;;
    *)
        rehearsal_usage
        exit 2
        ;;
    esac
    shift
done

[[ -n "$rehearsal_candidate" && -n "$rehearsal_rollback" ]] || {
    rehearsal_usage
    exit 2
}

rehearsal_candidate="$(cd -- "$rehearsal_candidate" 2> /dev/null && pwd -P)" ||
    rehearsal_fail "candidate directory is not accessible"
rehearsal_rollback="$(cd -- "$rehearsal_rollback" 2> /dev/null && pwd -P)" ||
    rehearsal_fail "rollback directory is not accessible"

for rehearsal_root in "$rehearsal_candidate" "$rehearsal_rollback"; do
    [[ -f "$rehearsal_root/lib/bash/base-bash-libs.release" ]] ||
        rehearsal_fail "framework metadata is missing under $rehearsal_root"
done

if [[ -n "$rehearsal_report" ]]; then
    rehearsal_report_dir="$(dirname -- "$rehearsal_report")"
    [[ -d "$rehearsal_report_dir" ]] || rehearsal_fail "report directory is missing"
    : > "$rehearsal_report" || rehearsal_fail "report is not writable"
    printf 'schema_version=1\n' >> "$rehearsal_report"
    printf 'bash=%s\n' "$BASH_VERSION" >> "$rehearsal_report"
    printf 'os=%s\n' "$(uname -s)" >> "$rehearsal_report"
fi

rehearsal_phase() {
    local phase="$1"
    local framework_root="$2"
    local app app_command status

    for app in installer release-helper ops-cli; do
        case "$app" in
        installer | ops-cli) app_command=status ;;
        release-helper) app_command=check ;;
        esac
        BASE_BASH_LIBS_DIR="$framework_root/lib/bash" \
            "$rehearsal_launcher" "$rehearsal_repo_root/examples/reference-apps/$app/bin/app" --help > /dev/null ||
            rehearsal_fail "$phase $app help failed"
        BASE_BASH_LIBS_DIR="$framework_root/lib/bash" \
            "$rehearsal_launcher" "$rehearsal_repo_root/examples/reference-apps/$app/bin/app" "$app_command" > /dev/null 2>&1
        status=$?
        [[ "$status" -eq 0 ]] || rehearsal_fail "$phase $app status failed with $status"
        if [[ -n "$rehearsal_report" ]]; then
            printf 'phase=%s\tapp=%s\tstatus=pass\n' "$phase" "$app" >> "$rehearsal_report"
        fi
    done
}

rehearsal_phase candidate "$rehearsal_candidate"
rehearsal_phase rollback "$rehearsal_rollback"

printf 'Reference release rehearsal passed: candidate and rollback apps=3.\n'
