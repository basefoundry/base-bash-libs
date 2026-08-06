#!/usr/bin/env bash

# Deterministic, dependency-free property checks for data-boundary APIs. A
# fixed seed makes failures reproducible in CI and in downstream bug reports.

property_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
property_repo_root="$(cd -- "$property_script_dir/.." && pwd -P)" || exit 1
property_tmp="$(mktemp -d "${TMPDIR:-/tmp}/base-bash-property-contract.XXXXXX")" || exit 1

property_cleanup() {
    rm -rf -- "$property_tmp"
}
trap property_cleanup EXIT

property_seed=20260806
property_case=0

property_fail() {
    printf 'Property contract failed: seed=%s case=%s: %s\n' \
        "$property_seed" "$property_case" "$*" >&2
    exit 1
}

property_next() {
    property_seed=$(( (property_seed * 1103515245 + 12345) % 2147483647 ))
    property_random_value="$property_seed"
}

property_value() {
    local output_name="$1" length index random_value property_index alphabet='abcXYZ012 -_*?[]()'
    local value=''
    property_next
    length=$((property_random_value % 28))
    for ((index = 0; index < length; index += 1)); do
        property_next
        random_value="$property_random_value"
        property_index=$((random_value % ${#alphabet}))
        value+="${alphabet:property_index:1}"
    done
    printf -v "$output_name" '%s' "$value"
}

property_assert_equal() {
    local label="$1" expected="$2" actual="$3"
    [[ "$expected" == "$actual" ]] || property_fail "$label expected <$expected>, got <$actual>"
}

# shellcheck source=/dev/null
source "$property_repo_root/lib/bash/std/lib_std.sh" || exit $?
# shellcheck source=/dev/null
source "$property_repo_root/lib/bash/str/lib_str.sh" || exit $?
# shellcheck source=/dev/null
source "$property_repo_root/lib/bash/arg/lib_arg.sh" || exit $?
# shellcheck source=/dev/null
source "$property_repo_root/lib/bash/file/lib_file.sh" || exit $?

# shellcheck disable=SC2034 # base_init publishes into this caller-owned array by name.
declare -a property_init_args=()
base_init property_init_args --source "$property_script_dir/property-contract.sh" -- || exit $?
base_std_set_log_level ERROR

# shellcheck disable=SC2034 # base_arg_parse consumes this caller-owned spec array by name.
property_specs=(
    'verbose|flag|--verbose|-v'
    'output|value|--output|-o'
    'property_includes|repeatable|--include|-I'
)

for ((property_case = 1; property_case <= 128; property_case += 1)); do
    generated=''
    property_value generated

    # Split/join must preserve arbitrary data, including empty fields and glob
    # characters, without invoking pathname expansion or command substitution.
    # shellcheck disable=SC2034 # base_str_split publishes into this array by name.
    property_parts=()
    property_joined=''
    base_str_split property_parts "$generated" '|'
    base_str_join property_joined '|' property_parts
    property_assert_equal 'split/join round trip' "$generated" "$property_joined"

    # Parser output is caller-owned data. Keep a marker outside the generated
    # value to detect accidental evaluation of command-like input.
    property_marker="$property_tmp/evaluated"
    rm -f -- "$property_marker"
    property_payload="$(printf '%s' "$generated" | sed 's/ /$(touch PLACEHOLDER)/')"
    property_payload=${property_payload//PLACEHOLDER/$property_marker}
    declare -A property_options=()
    declare -a property_positionals=() property_includes=()
    base_arg_parse property_options property_positionals property_specs -- \
        --verbose --output "$property_payload" --include "$property_payload" \
        "positional $generated" -- "literal $generated" ||
        property_fail 'argument parser rejected generated data'
    [[ ! -e "$property_marker" ]] || property_fail 'argument parser evaluated data input'
    property_assert_equal 'parsed value' "$property_payload" "${property_options[output]-}"
    property_assert_equal 'repeatable value' "$property_payload" "${property_includes[0]-}"
    property_assert_equal 'positional count' 2 "${#property_positionals[@]}"
    property_assert_equal 'positional with spaces' "positional $generated" "${property_positionals[0]-}"
    property_assert_equal 'escaped positional' "literal $generated" "${property_positionals[1]-}"

    # Marker edits are comparatively expensive because they snapshot the full
    # parent path. Sample them throughout the run without turning this into a
    # timeout test for the host filesystem.
    if ((property_case % 16 == 0)); then
        property_file="$property_tmp/section-$property_case"
        printf 'before\n' > "$property_file"
        base_file_update_file_section "$property_file" '# BEGIN PROPERTY' '# END PROPERTY' \
            "$generated" || property_fail 'marker insertion failed'
        base_file_update_file_section "$property_file" '# BEGIN PROPERTY' '# END PROPERTY' \
            "$generated" || property_fail 'marker idempotency failed'
        grep -F 'before' "$property_file" >/dev/null || property_fail 'marker edit lost outside content'
        base_file_section_exists "$property_file" '# BEGIN PROPERTY' '# END PROPERTY' ||
            property_fail 'marker section was not detected'
    fi
done

printf 'Property contract passed: cases=128 final-seed=%s.\n' "$property_seed"
