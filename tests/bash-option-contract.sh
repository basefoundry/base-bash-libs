#!/usr/bin/env bash

# Exercise the supported caller-runtime contract without depending on Bats so
# the same coverage can run inside the pinned, networkless Bash 4.2 image.

contract_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
contract_repo_root="$(cd -- "$contract_script_dir/.." && pwd -P)" || exit 1

contract_fail() {
    printf 'Bash option contract failed (%s): %s\n' "${contract_mode:-harness}" "$*" >&2
    exit 1
}

contract_assert_equal() {
    local label="${1-}" expected="${2-}" actual="${3-}"

    if [[ "$actual" != "$expected" ]]; then
        contract_fail "$label: expected '$expected', got '$actual'"
    fi
}

contract_assert_file_equal() {
    local label="${1-}" expected_file="${2-}" actual_file="${3-}"

    if ! cmp -s -- "$expected_file" "$actual_file"; then
        printf 'State before %s:\n' "$label" >&2
        sed 's/^/  /' "$expected_file" >&2
        printf 'State after %s:\n' "$label" >&2
        sed 's/^/  /' "$actual_file" >&2
        contract_fail "$label changed caller state"
    fi
}

contract_expect_status() {
    local label="${1-}" expected_status="${2-}" status
    shift 2

    if "$@"; then
        status=0
    else
        status=$?
    fi
    contract_assert_equal "$label status" "$expected_status" "$status"
}

contract_quiet_call() {
    "$@" >/dev/null 2>&1
}

contract_quiet_success() {
    local label="${1-}" status
    shift

    "$@" >/dev/null 2>&1
    status=$?
    contract_assert_equal "$label status" 0 "$status"
}

contract_quiet_subshell() {
    ("$@") >/dev/null 2>&1
}

contract_enable_mode() {
    case "$contract_mode" in
        e | eu | ep | eup) builtin set -o errexit ;;
    esac
    case "$contract_mode" in
        u | eu | up | eup) builtin set -o nounset ;;
    esac
    case "$contract_mode" in
        p | ep | up | eup) builtin set -o pipefail ;;
    esac
}

contract_assert_mode_options() {
    local expected_errexit=0 expected_nounset=0 expected_pipefail=0
    local actual_errexit=0 actual_nounset=0 actual_pipefail=0

    case "$contract_mode" in
        e | eu | ep | eup) expected_errexit=1 ;;
    esac
    case "$contract_mode" in
        u | eu | up | eup) expected_nounset=1 ;;
    esac
    case "$contract_mode" in
        p | ep | up | eup) expected_pipefail=1 ;;
    esac
    case "$-" in *e*) actual_errexit=1 ;; esac
    case "$-" in *u*) actual_nounset=1 ;; esac
    if [[ -o pipefail ]]; then
        actual_pipefail=1
    fi

    contract_assert_equal "errexit mode selection" "$expected_errexit" "$actual_errexit"
    contract_assert_equal "nounset mode selection" "$expected_nounset" "$actual_nounset"
    contract_assert_equal "pipefail mode selection" "$expected_pipefail" "$actual_pipefail"
}

contract_assert_version() {
    if (($# == 0)); then
        if ((BASH_VERSINFO[0] < 4 ||
            (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 2))); then
            contract_fail "requires Bash 4.2 or newer; running $BASH_VERSION"
        fi
        return 0
    fi

    if (($# != 3)); then
        contract_fail "usage: bash-option-contract.sh [expected_major expected_minor expected_patch]"
    fi
    contract_assert_equal "Bash major version" "$1" "${BASH_VERSINFO[0]}"
    contract_assert_equal "Bash minor version" "$2" "${BASH_VERSINFO[1]}"
    contract_assert_equal "Bash patch version" "$3" "${BASH_VERSINFO[2]}"
}

contract_snapshot_state() {
    local prefix="${1-}"

    set +o > "$prefix.set"
    shopt -p > "$prefix.shopt"
    printf '%s' "$IFS" > "$prefix.ifs"
    printf '%s\n' "$OPTIND" > "$prefix.optind"
    pwd -P > "$prefix.cwd"
    umask > "$prefix.umask"
    trap -p > "$prefix.traps"
}

contract_assert_state_unchanged() {
    local label="${1-}" before_prefix="${2-}" after_prefix="${3-}" state

    for state in set shopt ifs optind cwd umask traps; do
        contract_assert_file_equal "$label ($state)" \
            "$before_prefix.$state" "$after_prefix.$state"
    done
}

contract_source_module() {
    local module_path="${1-}" module_name before_prefix after_prefix
    module_name="${module_path##*/}"
    contract_state_index=$((contract_state_index + 1))
    before_prefix="$contract_tmp/state-$contract_state_index-before"
    after_prefix="$contract_tmp/state-$contract_state_index-after"

    set -- "argument with spaces" "" "literal-*"
    contract_snapshot_state "$before_prefix"
    # shellcheck disable=SC1090 # The matrix intentionally sources each absolute module path.
    source "$module_path"
    contract_snapshot_state "$after_prefix"

    contract_assert_state_unchanged "$module_name sourcing" "$before_prefix" "$after_prefix"
    contract_assert_equal "$module_name positional count" 3 "$#"
    contract_assert_equal "$module_name positional 1" "argument with spaces" "${1-}"
    contract_assert_equal "$module_name positional 2" "" "${2-}"
    contract_assert_equal "$module_name positional 3" "literal-*" "${3-}"
}

contract_top_level_source_probe() {
    local status

    "$BASH" -c '
        contract_mode=$1
        shift
        contract_modules=("$@")
        case "$contract_mode" in
            e | eu | ep | eup) builtin set -o errexit ;;
        esac
        case "$contract_mode" in
            u | eu | up | eup) builtin set -o nounset ;;
        esac
        case "$contract_mode" in
            p | ep | up | eup) builtin set -o pipefail ;;
        esac
        IFS="| "
        OPTIND=7
        umask 027
        shopt -s extglob nullglob nocasematch
        trap ":" EXIT HUP INT TERM
        for contract_module in "${contract_modules[@]}"; do
            set -- "argument with spaces" "" "literal-*"
            source "$contract_module"
            [[ $# == 3 && ${1-} == "argument with spaces" && -z ${2-} && ${3-} == "literal-*" ]] || exit 1
        done
    ' bash "$contract_mode" "$@"
    status=$?
    contract_assert_equal "top-level bash -c source probe status" 0 "$status"
}

contract_run_api_smoke() {
    local label="${1-}" smoke_function="${2-}" status
    local before_prefix after_prefix
    contract_state_index=$((contract_state_index + 1))
    before_prefix="$contract_tmp/state-$contract_state_index-before"
    after_prefix="$contract_tmp/state-$contract_state_index-after"

    set -- "api argument with spaces" "" "api-literal-*"
    contract_snapshot_state "$before_prefix"
    "$smoke_function"
    status=$?
    contract_assert_equal "$label success" 0 "$status"
    contract_snapshot_state "$after_prefix"

    contract_assert_state_unchanged "$label public API calls" "$before_prefix" "$after_prefix"
    contract_assert_equal "$label API positional count" 3 "$#"
    contract_assert_equal "$label API positional 1" "api argument with spaces" "${1-}"
    contract_assert_equal "$label API positional 2" "" "${2-}"
    contract_assert_equal "$label API positional 3" "api-literal-*" "${3-}"
}

contract_std_api_smoke() {
    local contract_path_output="" contract_source_dir="" contract_command_path=""
    local contract_original_path="$PATH"
    # shellcheck disable=SC2034 # Public APIs consume these variables by name.
    local contract_temp_file="" contract_temp_dir="" contract_number=7
    local contract_log_file="$contract_tmp/log-input"
    local contract_created_dir="$contract_tmp/created/child"
    local contract_created_file="$contract_tmp/created/file"

    check_bash_version
    base_bash_libs_require_version 0.0.0

    PATH="/bin:/usr/bin:/bin"
    dedupe_path
    contract_assert_equal "dedupe_path" "/bin:/usr/bin" "$PATH"
    add_to_path -n "$contract_tmp/tools"
    contract_path_output="$(print_path)"
    contract_assert_equal "print_path" $'/bin\n/usr/bin\n'"$contract_tmp/tools" "$contract_path_output"
    PATH="$contract_original_path"

    set_log_level DEBUG
    set_log_category_level -l contract DEBUG
    log_is_enabled -l contract DEBUG
    contract_expect_status "disabled log predicate" 1 log_is_enabled -l contract VERBOSE
    printf 'line one\nline two\n' > "$contract_log_file"
    contract_quiet_success "log_info" log_info "option contract"
    contract_quiet_success "log_debug" log_debug -l contract "debug contract"
    contract_quiet_success "log_info_file" log_info_file "$contract_log_file"
    contract_quiet_success "log_info_enter" log_info_enter
    contract_quiet_success "log_info_leave" log_info_leave
    contract_quiet_success "dump_trace" dump_trace
    contract_quiet_success "print_error" print_error "expected diagnostic"
    contract_quiet_success "print_warn" print_warn "expected diagnostic"
    contract_quiet_success "print_info" print_info "expected diagnostic"
    contract_quiet_success "print_success" print_success "expected diagnostic"
    contract_quiet_success "print_bold" print_bold "expected output"
    contract_quiet_success "print_message" print_message "expected output"
    print_tty "non-interactive output"

    std_run --no-exit --quiet "$BASH" -c 'exit 0'
    contract_expect_status "std_run recoverable failure" 7 \
        contract_quiet_call std_run --no-exit --quiet "$BASH" -c 'exit 7'
    contract_expect_status "std_run usage" 1 contract_quiet_call std_run
    # shellcheck disable=SC2034 # is_dry_run reads the conventional global by name.
    DRY_RUN=1
    contract_quiet_success "std_run dry run" \
        std_run --no-exit --quiet command-that-must-not-run
    unset DRY_RUN
    contract_expect_status "is_dry_run false predicate" 1 is_dry_run
    # shellcheck disable=SC2034 # is_dry_run reads the compatibility global by name.
    dry_run=yes
    is_dry_run
    unset dry_run

    safe_mkdir -p "$contract_created_dir"
    safe_touch "$contract_created_file"
    printf 'content\n' > "$contract_created_file"
    safe_truncate "$contract_created_file"
    contract_assert_equal "safe_truncate size" 0 "$(wc -c < "$contract_created_file" | tr -d ' ')"

    std_make_temp_file --keep contract_temp_file option-contract
    std_make_temp_dir --keep contract_temp_dir option-contract
    [[ -f "$contract_temp_file" ]] || contract_fail "std_make_temp_file did not create a file"
    [[ -d "$contract_temp_dir" ]] || contract_fail "std_make_temp_dir did not create a directory"

    contract_cleanup_hook() { :; }
    std_register_cleanup_hook contract_cleanup_hook
    std_unregister_cleanup_hook contract_cleanup_hook
    std_register_cleanup_path "$contract_temp_file"
    std_unregister_cleanup_path "$contract_temp_file"

    std_command_path contract_command_path bash
    [[ -n "$contract_command_path" ]] || contract_fail "std_command_path did not resolve bash"
    std_function_exists contract_std_api_smoke
    contract_expect_status "std_function_exists false predicate" 1 \
        std_function_exists contract_missing_function
    assert_function_exists contract_std_api_smoke
    assert_variable_name contract_number contract_source_dir
    # shellcheck disable=SC2034 # Assertion APIs consume these declarations by name.
    declare -a contract_indexed_array=()
    # shellcheck disable=SC2034 # Assertion APIs consume these declarations by name.
    declare -A contract_associative_array=()
    assert_indexed_array contract_indexed_array
    assert_associative_array contract_associative_array
    assert_not_null contract_number
    assert_integer contract_number
    assert_integer_range contract_number 1 9
    assert_arg_count 2 1 3
    assert_command_exists bash
    assert_file_exists "$contract_created_file"
    assert_executable "$BASH"
    assert_dir_exists "$contract_created_dir"

    get_my_source_dir contract_source_dir
    [[ -n "$contract_source_dir" ]] || contract_fail "get_my_source_dir returned an empty path"
    contract_source_dir="$(pwd -P)"
    contract_created_dir="$(cd -- "$contract_created_dir" && pwd -P)"
    safe_cd "$contract_created_dir"
    contract_assert_equal "safe_cd destination" "$contract_created_dir" "$(pwd -P)"
    safe_cd "$contract_source_dir"
    alias contract_alias='printf alias'
    safe_unalias contract_alias contract_missing_alias
    contract_expect_status "ask_yes_no usage" 1 contract_quiet_call ask_yes_no
    contract_expect_status "wait_for_enter usage" 1 contract_quiet_call wait_for_enter one two
    contract_expect_status "exit_if_error status preservation" 7 \
        contract_quiet_subshell exit_if_error 7 "expected contract failure"
    contract_expect_status "fatal_error status" 1 \
        contract_quiet_subshell fatal_error "expected contract failure"
}

contract_str_api_smoke() {
    local contract_value="  Mixed Case  " contract_joined=""
    # shellcheck disable=SC2034 # str_join consumes the empty array by name.
    local -a contract_parts=() contract_empty_parts=()

    str_trim contract_value
    contract_assert_equal "str_trim" "Mixed Case" "$contract_value"
    str_lower contract_value
    contract_assert_equal "str_lower" "mixed case" "$contract_value"
    str_upper contract_value
    contract_assert_equal "str_upper" "MIXED CASE" "$contract_value"
    contract_value="  left"
    str_ltrim contract_value
    contract_assert_equal "str_ltrim" "left" "$contract_value"
    contract_value="right  "
    str_rtrim contract_value
    contract_assert_equal "str_rtrim" "right" "$contract_value"
    str_contains "option-contract" "contract"
    str_starts_with "option-contract" "option"
    str_ends_with "option-contract" "contract"
    contract_expect_status "str predicate false" 1 str_contains "option-contract" "missing"

    str_split contract_parts "alpha,,omega," ","
    contract_assert_equal "str_split length" 4 "${#contract_parts[@]}"
    contract_assert_equal "str_split empty field" "" "${contract_parts[1]-}"
    contract_assert_equal "str_split trailing field" "" "${contract_parts[3]-}"
    str_join contract_joined "|" contract_parts
    contract_assert_equal "str_join" "alpha||omega|" "$contract_joined"
    str_join contract_joined "|" contract_empty_parts
    contract_assert_equal "str_join empty array" "" "$contract_joined"
    contract_expect_status "str_lower usage" 1 contract_quiet_subshell str_lower
}

contract_list_api_smoke() {
    local contract_length=""
    # shellcheck disable=SC2034 # List APIs consume these arrays by name.
    local -a contract_values=(beta alpha beta) contract_unique=() contract_empty=()

    list_append contract_values omega
    list_prepend contract_values zero
    list_remove contract_values beta
    list_contains alpha contract_values
    contract_expect_status "list_contains false predicate" 1 list_contains missing contract_values
    list_unique contract_unique contract_values
    contract_assert_equal "list_unique length" 3 "${#contract_unique[@]}"
    contract_assert_equal "list_unique first" zero "${contract_unique[0]-}"
    contract_assert_equal "list_unique last" omega "${contract_unique[2]-}"
    list_length contract_length contract_values
    contract_assert_equal "list_length" 3 "$contract_length"

    list_unique contract_unique contract_empty
    [[ -z "${contract_unique[0]+set}" ]] || contract_fail "list_unique did not publish an empty array"
    list_length contract_length contract_empty
    contract_assert_equal "list_length empty array" 0 "$contract_length"
    contract_expect_status "list_append usage" 1 contract_quiet_subshell list_append
}

contract_arg_api_smoke() {
    local -A contract_options=()
    local -a contract_positionals=() contract_includes=()
    # shellcheck disable=SC2034 # arg_parse consumes the specification by name.
    local -a contract_specs=(
        "verbose|flag|--verbose|-v"
        "output|value|--output|-o"
        "contract_includes|repeatable|--include|-I"
    )

    arg_parse contract_options contract_positionals contract_specs -- \
        --verbose --output=result --include one --include=two "first positional" -- -x
    contract_assert_equal "arg_parse flag" 1 "${contract_options[verbose]-}"
    contract_assert_equal "arg_parse value" result "${contract_options[output]-}"
    contract_assert_equal "arg_parse positional count" 2 "${#contract_positionals[@]}"
    contract_assert_equal "arg_parse positional" "first positional" "${contract_positionals[0]-}"
    contract_assert_equal "arg_parse option-like positional" -x "${contract_positionals[1]-}"
    contract_assert_equal "arg_parse repeatable count" 2 "${#contract_includes[@]}"
    contract_assert_equal "arg_parse repeatable last" two "${contract_includes[1]-}"

    contract_expect_status "arg_parse unknown option" 2 contract_quiet_call \
        arg_parse contract_options contract_positionals contract_specs -- --unknown
    contract_expect_status "arg_parse usage" 2 contract_quiet_call arg_parse

    declare -A contract_empty_options=()
    # shellcheck disable=SC2034 # arg_parse consumes the empty arrays by name.
    declare -a contract_empty_positionals=() contract_empty_specs=()
    arg_parse contract_empty_options contract_empty_positionals contract_empty_specs --
    [[ -z "${contract_empty_options[0]+set}" ]] || contract_fail "arg_parse did not publish empty options"
    [[ -z "${contract_empty_positionals[0]+set}" ]] || contract_fail "arg_parse did not publish empty positionals"
}

contract_file_api_smoke() {
    local contract_target="$contract_tmp/section-file"

    printf 'prefix\n' > "$contract_target"
    contract_quiet_success "update_file_section add" update_file_section \
        "$contract_target" "# BEGIN CONTRACT" "# END CONTRACT" "alpha" "beta"
    file_section_exists "$contract_target" "# BEGIN CONTRACT" "# END CONTRACT"
    contract_expect_status "file section unchanged predicate" 1 file_section_needs_update \
        "$contract_target" "# BEGIN CONTRACT" "# END CONTRACT" "alpha" "beta"
    file_section_needs_update \
        "$contract_target" "# BEGIN CONTRACT" "# END CONTRACT" "replacement"
    contract_quiet_success "update_file_section replace" update_file_section \
        "$contract_target" "# BEGIN CONTRACT" "# END CONTRACT" "replacement"
    contract_quiet_success "update_file_section remove" update_file_section \
        -r "$contract_target" "# BEGIN CONTRACT" "# END CONTRACT"
    contract_expect_status "file section absent predicate" 1 file_section_exists \
        "$contract_target" "# BEGIN CONTRACT" "# END CONTRACT"
    contract_expect_status "file_section_exists usage" 2 contract_quiet_call file_section_exists
    contract_expect_status "file_section_needs_update usage" 2 \
        contract_quiet_call file_section_needs_update
    contract_expect_status "update_file_section usage" 1 contract_quiet_call update_file_section
}

contract_git_stub() {
    if [[ "${1-}" == "-C" ]]; then
        shift 2
    fi

    case "${1-}" in
        symbolic-ref)
            if [[ "${4-}" == "refs/remotes/origin/HEAD" ]]; then
                printf 'origin/main\n'
            else
                printf 'main\n'
            fi
            ;;
        show-ref | merge-base)
            return 0
            ;;
        worktree)
            printf 'worktree /contract/worktree\nHEAD 0123456789\nbranch refs/heads/main\n\n'
            ;;
        for-each-ref)
            printf 'origin/main\n'
            ;;
        ls-remote)
            printf '0123456789abcdef\trefs/heads/main\n'
            printf 'fedcba9876543210\trefs/heads/topic/one\n'
            ;;
        remote)
            printf 'git@github.com:basefoundry/base-bash-libs.git\n'
            ;;
        rev-parse)
            case "${2-}" in
                --is-inside-work-tree) printf 'true\n' ;;
                --show-toplevel) printf '%s\n' "$contract_tmp" ;;
                --show-prefix) printf '\n' ;;
                *) return 1 ;;
            esac
            ;;
        *)
            return 0
            ;;
    esac
}

contract_gh_stub() {
    local status="${CONTRACT_GH_STATUS:-0}"

    if ((status != 0)); then
        return "$status"
    fi
    case "${1-}:${2-}" in
        repo:view) printf 'main\n' ;;
        api:*) printf '{"contract":true}\n' ;;
    esac
    return 0
}

contract_git_gh_api_smoke() {
    local contract_result="" contract_output=""

    git() { contract_git_stub "$@"; }
    gh() { contract_gh_stub "$@"; }

    git_detect_default_branch /contract/repo contract_result
    contract_assert_equal "git_detect_default_branch" main "$contract_result"
    contract_output="$(git_worktree_path_for_branch main /contract/repo)"
    contract_assert_equal "git_worktree_path_for_branch" /contract/worktree "$contract_output"
    contract_output="$(git_list_worktree_branches /contract/repo)"
    contract_assert_equal "git_list_worktree_branches" $'/contract/worktree\tmain' "$contract_output"
    contract_output="$(git_branch_upstream /contract/repo main)"
    contract_assert_equal "git_branch_upstream" origin/main "$contract_output"
    git_branch_merged_to_ref /contract/repo main origin/main
    contract_output="$(git_list_remote_branches /contract/repo)"
    contract_assert_equal "git_list_remote_branches" $'main\ntopic/one' "$contract_output"
    git_get_current_branch "$contract_tmp" contract_result
    contract_assert_equal "git_get_current_branch" main "$contract_result"
    contract_quiet_success "check_script_up_to_date missing file" \
        check_script_up_to_date "$contract_tmp/missing-script"

    contract_expect_status "git_detect_default_branch usage" 1 contract_quiet_call git_detect_default_branch
    contract_expect_status "git_worktree_path_for_branch usage" 1 contract_quiet_call git_worktree_path_for_branch
    contract_expect_status "git_list_worktree_branches usage" 1 \
        contract_quiet_call git_list_worktree_branches one two
    contract_expect_status "git_branch_upstream usage" 1 contract_quiet_call git_branch_upstream
    contract_expect_status "git_branch_merged_to_ref usage" 1 contract_quiet_call git_branch_merged_to_ref
    contract_expect_status "git_list_remote_branches usage" 1 \
        contract_quiet_call git_list_remote_branches one two
    contract_expect_status "git_update_repo usage" 1 contract_quiet_call git_update_repo
    contract_expect_status "git_get_current_branch usage" 1 contract_quiet_call git_get_current_branch
    contract_expect_status "check_script_up_to_date usage" 1 contract_quiet_call check_script_up_to_date

    gh_require_cli
    gh_auth_status_diagnostics
    contract_quiet_success "gh_run" gh_run repo view basefoundry/base-bash-libs
    gh_repo_from_remote_url git@github.com:basefoundry/base-bash-libs.git contract_result
    contract_assert_equal "gh_repo_from_remote_url" basefoundry/base-bash-libs "$contract_result"
    gh_infer_repo_from_origin /contract/repo contract_result
    contract_assert_equal "gh_infer_repo_from_origin" basefoundry/base-bash-libs "$contract_result"
    gh_repo_default_branch basefoundry/base-bash-libs contract_result
    contract_assert_equal "gh_repo_default_branch" main "$contract_result"
    contract_output="$(gh_api_with_retry repos/basefoundry/base-bash-libs)"
    contract_assert_equal "gh_api_with_retry" '{"contract":true}' "$contract_output"
    contract_expect_status "gh_report_command_failure status" 7 contract_quiet_call \
        gh_report_command_failure 7 api contract
    CONTRACT_GH_STATUS=255
    contract_expect_status "gh_run failure status" 255 contract_quiet_call gh_run api contract
    unset CONTRACT_GH_STATUS

    contract_expect_status "gh_require_cli usage" 1 contract_quiet_call gh_require_cli one two
    contract_expect_status "gh_auth_status_diagnostics usage" 1 \
        contract_quiet_call gh_auth_status_diagnostics one two
    contract_expect_status "gh_report_command_failure usage" 1 \
        contract_quiet_call gh_report_command_failure
    contract_expect_status "gh_repo_from_remote_url usage" 1 \
        contract_quiet_call gh_repo_from_remote_url
    contract_expect_status "gh_infer_repo_from_origin usage" 1 \
        contract_quiet_call gh_infer_repo_from_origin
    contract_expect_status "gh_repo_default_branch usage" 1 \
        contract_quiet_call gh_repo_default_branch
}

contract_run_mode() {
    local module
    local -a modules=(
        "$contract_repo_root/lib/bash/std/lib_std.sh"
        "$contract_repo_root/lib/bash/file/lib_file.sh"
        "$contract_repo_root/lib/bash/git/lib_git.sh"
        "$contract_repo_root/lib/bash/gh/lib_gh.sh"
        "$contract_repo_root/lib/bash/str/lib_str.sh"
        "$contract_repo_root/lib/bash/arg/lib_arg.sh"
        "$contract_repo_root/lib/bash/list/lib_list.sh"
    )

    contract_assert_version "$@"
    contract_tmp="$(mktemp -d "${TMPDIR:-/tmp}/base-bash-option-contract.XXXXXX")" ||
        contract_fail "unable to create temporary directory"
    export TMPDIR="$contract_tmp"
    contract_state_index=0
    trap 'rm -rf -- "$contract_tmp"' EXIT
    trap ':' HUP INT TERM
    IFS=$'| \t\n'
    OPTIND=7
    umask 027
    shopt -s extglob nullglob nocasematch
    cd -- "$contract_tmp" || contract_fail "unable to enter temporary directory"

    contract_enable_mode
    contract_assert_mode_options
    contract_top_level_source_probe "${modules[@]}"
    for module in "${modules[@]}"; do
        contract_source_module "$module"
    done

    contract_run_api_smoke std contract_std_api_smoke
    contract_run_api_smoke str contract_str_api_smoke
    contract_run_api_smoke list contract_list_api_smoke
    contract_run_api_smoke arg contract_arg_api_smoke
    contract_run_api_smoke file contract_file_api_smoke
    contract_run_api_smoke git-and-gh contract_git_gh_api_smoke

    printf 'Bash option contract passed: %s (%s)\n' "$contract_mode" "$BASH_VERSION"
}

if [[ "${1-}" == "--mode" ]]; then
    if (($# < 2)); then
        contract_fail "--mode requires a value"
    fi
    contract_mode="$2"
    shift 2
    case "$contract_mode" in
        none | e | u | p | eu | ep | up | eup) ;;
        *) contract_fail "unknown option mode '$contract_mode'" ;;
    esac
    contract_run_mode "$@"
    exit 0
fi

if (($# != 0 && $# != 3)); then
    contract_fail "usage: bash-option-contract.sh [expected_major expected_minor expected_patch]"
fi

contract_modes=(none e u p eu ep up eup)
for contract_requested_mode in "${contract_modes[@]}"; do
    if "$BASH" "$contract_script_dir/bash-option-contract.sh" \
        --mode "$contract_requested_mode" "$@"; then
        :
    else
        contract_status=$?
        printf 'Bash option mode %s failed with status %s.\n' \
            "$contract_requested_mode" "$contract_status" >&2
        exit "$contract_status"
    fi
done

printf 'All Bash option combinations passed (%s).\n' "$BASH_VERSION"
