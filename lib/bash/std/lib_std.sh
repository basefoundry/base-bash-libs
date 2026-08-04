# shellcheck shell=bash
#
# lib_std.sh - Foundation library for Bash scripts
#              Requires Bash 4.2 or higher.
#
# This library provides a standardized set of functions for common tasks,
# ensuring consistency and robustness across multiple scripts.
#
# Areas covered:
#     - PATH manipulation
#     - Logging (with levels and colors)
#     - Error handling and stack tracing
#     - Bash version check helpers
#     - Library importing
#     - Miscellaneous helpers
#
# Quick Reference
# --------------------------------------------------------------------------------------------------------------------
# Sourcing:
#   source "<repo>/lib/bash/std/lib_std.sh"
#
# Caller-visible metadata:
#   BASE_BASH_LIBS_VERSION
#                    Package version read from the repository/package VERSION file.
#   BASE_BASH_LIBS_STDLIB_LOADED
#                    Set to 1 after lib_std.sh has been loaded successfully.
#
# Runtime globals such as __SCRIPT_ARGS__ and __SCRIPT_DIR__ are published only
# by base_bash_libs_init. Sourcing this file never consumes or rewrites "$@".
#
# Core helpers:
#   std_run [opts] cmd ...
#                                # Safe command runner with dry-run, timeout, retry & failure handling.
#   exit_if_error rc msg...      # Log + exit when rc != 0 (preserves original status).
#   fatal_error msg...           # Convenience wrapper: exit with last status or 1.
#   std_register_cleanup_hook fn # Run a cleanup function from the shared EXIT trap.
#   std_register_cleanup_path p  # Remove owned files/directories from EXIT cleanup.
#   std_register_cleanup_path --unsafe p
#                                # Explicitly opt out of path-identity proof.
#   std_unregister_cleanup_path p
#                                # Drop files/directories from the shared EXIT cleanup list.
#   std_make_temp_file var [pfx] # Create a temp file and store its path in var.
#   std_make_temp_dir var [pfx]  # Create a temp directory and store its path in var.
#   std_command_path var cmd     # Resolve an external command path without exiting.
#   std_function_exists fn       # Predicate for defined Bash functions.
#   assert_variable_name name    # Validate Bash variable-name arguments.
#   assert_associative_array map # Validate caller-declared associative arrays.
#   base_bash_libs_require_version min_version
#                                # Exit clearly if the loaded library is too old.
#   add_to_path [-n] [-p] dir    # Append/prepend unique PATH entries.
#   set_log_level [LEVEL]        # Adjust terminal verbosity (FATAL..VERBOSE).
#   set_log_category_level -l category LEVEL
#                                # Gate a category independently of its sinks.
#   log_is_enabled [-l category] LEVEL
#                                # Test whether any configured sink accepts a level.
#   log_info/debug/... msgs      # Structured logging (color in interactive shells).
#   safe_touch file [...]        # touch wrapper that exits on failure (same for safe_truncate).
#   assert_* utilities           # Validation helpers (assert_not_null / assert_integer / ...).
#
# Patterns:
#   std_run some_cmd             # exits on failure; DRY_RUN=true/1/yes/on prints instead.
#   std_run --timeout 30 some_cmd
#                                # bounds the command attempt to 30 seconds.
#   std_run --max-attempts 3 --retry-delay 2 some_cmd
#                                # retries transient failures.
#   some_cmd || fatal_error ...  # preserves failing exit code before terminating.
#   add_to_path -p "/opt/tools"  # inject directories without duplicates.
#
# Notes:
#   - Call base_bash_libs_init <result_array> [--source <script>] [--] [argv...]
#     before using stateful helpers. It strips --debug-wrapper,
#     --verbose-wrapper, --utc-wrapper, and --color into the result array.
#   - --verbose-wrapper is deprecated compatibility surface; prefer --debug-wrapper.
#   - BASE_BASH_BOOTSTRAP_SOURCE is accepted as a source-path fallback by the
#     explicit initializer, not consumed while this file is sourced.
#

################################################# INITIALIZATION #######################################################

__lib_std_require_supported_bash__() {
    if [[ -z "${BASH_VERSION:-}" ]]; then
        printf '%s\n' "Error: This script requires Bash 4.2 or higher." >&2
        printf '%s\n' "Your shell is not Bash." >&2
        return 1
    fi
    if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 2))); then
        printf '%s\n' "Error: This script requires Bash 4.2 or higher." >&2
        printf '%s\n' "Your version ($BASH_VERSION) is not compatible." >&2
        return 1
    fi
}

# Runtime state remains passive, but loading an unsupported interpreter is a
# deterministic contract error rather than a partially-defined library.
__lib_std_require_supported_bash__ || return 1 2>/dev/null || exit 1
unset -f __lib_std_require_supported_bash__

__base_bash_libs_read_package_version__() {
    local source_path="${1-}" version_file version

    [[ -n "$source_path" ]] || return 1
    version_file="$(cd -- "$(dirname -- "$source_path")/../../.." &>/dev/null && pwd -P)/VERSION" || return 1
    [[ -r "$version_file" ]] || {
        printf '%s\n' "Error: base-bash-libs VERSION file is not readable: $version_file" >&2
        return 1
    }
    IFS= read -r version < "$version_file" || [[ -n "$version" ]] || {
        printf '%s\n' "Error: Unable to read base-bash-libs version from: $version_file" >&2
        return 1
    }
    [[ -n "$version" ]] || {
        printf '%s\n' "Error: base-bash-libs VERSION file is empty: $version_file" >&2
        return 1
    }
    printf '%s' "$version"
}

# A source guard is deliberately package-prefixed and readonly. It is the only
# source-time state other than immutable package metadata. Re-sourcing the same
# version is a no-op; attempting to mix versions fails before definitions are
# replaced.
if [[ -n "${BASE_BASH_LIBS_STD_SOURCE_GUARD+x}" ]]; then
    if [[ "${BASE_BASH_LIBS_STD_SOURCE_VERSION-}" != "$(__base_bash_libs_read_package_version__ "${BASH_SOURCE[0]}")" ||
        "${BASE_BASH_LIBS_STD_SOURCE_PATH-}" != "${BASH_SOURCE[0]}" ]]; then
        printf '%s\n' "Error: incompatible base-bash-libs stdlib versions or sources are already loaded (loaded ${BASE_BASH_LIBS_STD_SOURCE_VERSION:-unknown} from ${BASE_BASH_LIBS_STD_SOURCE_PATH:-unknown}, requested $(__base_bash_libs_read_package_version__ "${BASH_SOURCE[0]}" 2>/dev/null || printf 'unknown') from ${BASH_SOURCE[0]})." >&2
        unset -f __base_bash_libs_read_package_version__
        return 1 2>/dev/null || exit 1
    fi
    unset -f __base_bash_libs_read_package_version__
    return 0
fi

if [[ -n "${BASE_BASH_LIBS_VERSION+x}" || -n "${BASE_BASH_LIBS_STDLIB_LOADED+x}" ]]; then
    printf '%s\n' "Error: base-bash-libs metadata names are already owned by the caller; refusing to overwrite them." >&2
    return 1 2>/dev/null || exit 1
fi

readonly BASE_BASH_LIBS_STD_SOURCE_PATH="${BASH_SOURCE[0]}"
readonly BASE_BASH_LIBS_STD_ROOT="$(cd -- "$(dirname -- "$BASE_BASH_LIBS_STD_SOURCE_PATH")/../../.." &>/dev/null && pwd -P)" || {
    printf '%s\n' "Error: Unable to resolve base-bash-libs root from '$BASE_BASH_LIBS_STD_SOURCE_PATH'." >&2
    return 1 2>/dev/null || exit 1
}
BASE_BASH_LIBS_VERSION="$(__base_bash_libs_read_package_version__ "$BASE_BASH_LIBS_STD_SOURCE_PATH")" || {
    return 1 2>/dev/null || exit 1
}
readonly BASE_BASH_LIBS_VERSION
readonly BASE_BASH_LIBS_STD_SOURCE_VERSION="$BASE_BASH_LIBS_VERSION"
readonly BASE_BASH_LIBS_STD_SOURCE_GUARD=1
# Used by companion libraries as a source-order guard. This marker means the
# definitions and immutable metadata are loaded; it does not imply runtime init.
# shellcheck disable=SC2034
readonly BASE_BASH_LIBS_STDLIB_LOADED=1
unset -f __base_bash_libs_read_package_version__

__base_bash_libs_is_dotted_numeric_version__() {
    local version="${1-}" version_re='^[0-9]+([.][0-9]+)*$'
    [[ "$version" =~ $version_re ]]
}

__base_bash_libs_version_at_least__() {
    local actual_version="$1" minimum_version="$2"
    local -a actual_parts=() minimum_parts=()
    local index max_parts actual_part minimum_part actual_number minimum_number

    IFS=. read -r -a actual_parts <<<"$actual_version"
    IFS=. read -r -a minimum_parts <<<"$minimum_version"

    max_parts="${#actual_parts[@]}"
    if ((${#minimum_parts[@]} > max_parts)); then
        max_parts="${#minimum_parts[@]}"
    fi

    for ((index = 0; index < max_parts; index++)); do
        actual_part="${actual_parts[$index]:-0}"
        minimum_part="${minimum_parts[$index]:-0}"
        actual_number=$((10#$actual_part))
        minimum_number=$((10#$minimum_part))

        if ((actual_number > minimum_number)); then
            return 0
        fi
        if ((actual_number < minimum_number)); then
            return 1
        fi
    done

    return 0
}

#
# base_bash_libs_require_version - Requires a minimum base-bash-libs version.
#
# Usage:
#   base_bash_libs_require_version 1.1.0
#
base_bash_libs_require_version() {
    local minimum_version="${1-}"

    assert_arg_count "$#" 1

    if ! __base_bash_libs_is_dotted_numeric_version__ "$minimum_version" ||
        ! __base_bash_libs_is_dotted_numeric_version__ "$BASE_BASH_LIBS_VERSION"; then
        fatal_error "base_bash_libs_require_version expects dotted numeric versions."
    fi

    if ! __base_bash_libs_version_at_least__ "$BASE_BASH_LIBS_VERSION" "$minimum_version"; then
        fatal_error "base-bash-libs $minimum_version or newer is required; loaded version is $BASE_BASH_LIBS_VERSION."
    fi

    return 0
}

############################################ BASH VERSION CHECKER #######################################################

#
# is_interactive - Checks if the current shell is interactive.
#
# An interactive shell is one where the user is typing commands directly.
# This is used to determine if we can safely prompt the user for input.
#
# Returns:
#   0 (true) if the shell is interactive.
#   1 (false) if the shell is not interactive (e.g., running in a cron job).
#
is_interactive() {
    [[ -t 0 ]]
}

#
# check_bash_version - Verifies the Bash version without prompting or installing anything.
#
# This function checks if the running Bash interpreter is version 4.2 or higher and returns
# non-zero when it is not. Base entrypoints should enforce the supported runtime before
# sourcing this library; this helper is intentionally passive so sourcing lib_std.sh never
# prompts, installs packages, or re-execs the caller.
#
# Note: This function is called before logging is initialized, so it uses `echo` to stderr.
#
check_bash_version() {
    local bash_major bash_minor test_version

    if [[ -n "${BASE_TEST_BASH_VERSION:-}" ]]; then
        test_version="$BASE_TEST_BASH_VERSION"
        if [[ "$test_version" == *.* ]]; then
            bash_major="${test_version%%.*}"
            bash_minor="${test_version#*.}"
        else
            bash_major="${test_version:0:1}"
            bash_minor="${test_version:1}"
        fi
    else
        bash_major="${BASH_VERSINFO[0]}"
        bash_minor="${BASH_VERSINFO[1]}"
    fi
    bash_minor="${bash_minor:-0}"

    if ((bash_major < 4 || (bash_major == 4 && bash_minor < 2))); then
        echo "Error: This script requires Bash 4.2 or higher." >&2
        echo "Your version ($BASH_VERSION) is not compatible." >&2
        return 1
    fi
}

###################################################### INIT ############################################################

__std_init_validate_result_array__() {
    local result_name="${1-}" declaration attributes nocasematch_enabled=0 attributes_ok=0

    [[ "$result_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || {
        printf '%s\n' "base_bash_libs_init: result name must be a valid Bash variable name." >&2
        return 1
    }
    [[ "$result_name" != __* ]] || {
        printf '%s\n' "base_bash_libs_init: result name '$result_name' uses the reserved internal namespace." >&2
        return 1
    }
    declaration="$(declare -p "$result_name" 2>/dev/null || true)"
    [[ -n "$declaration" ]] || {
        printf '%s\n' "base_bash_libs_init: result '$result_name' must be a caller-declared indexed array." >&2
        return 1
    }
    attributes="${declaration#declare -}"
    attributes="${attributes%% *}"
    if shopt -q nocasematch; then
        nocasematch_enabled=1
        shopt -u nocasematch
    fi
    if [[ "$attributes" == *a* &&
        "$attributes" != *A* &&
        "$attributes" != *r* ]]; then
        attributes_ok=1
    fi
    if ((nocasematch_enabled)); then
        shopt -s nocasematch
    fi
    ((attributes_ok)) || {
        printf '%s\n' "base_bash_libs_init: result '$result_name' must be a caller-declared indexed array." >&2
        return 1
    }
}

__std_init_publish_array__() {
    local result_name="$1" value
    shift
    eval "$result_name=()"
    for value; do
        eval "$result_name+=(\"\$value\")"
    done
}

__std_init_args_match__() {
    local index=0
    (($# == ${#__SCRIPT_ARGS__[@]})) || return 1
    for index in "${!__SCRIPT_ARGS__[@]}"; do
        [[ "${__SCRIPT_ARGS__[$index]}" == "$1" ]] || return 1
        shift
    done
}

__std_initialize_runtime_state__() {
    local script_dir="$1"
    shift

    if [[ -n "${BASE_BASH_LIBS_STD_INITIALIZED+x}" ]]; then
        [[ "${BASE_BASH_LIBS_STD_INITIALIZED}" == 1 ]] || {
            printf '%s\n' "base_bash_libs_init: runtime state marker is owned by the caller." >&2
            return 1
        }
        return 0
    fi

    if [[ -n "${BASE_BASH_LIBS_STD_INIT_SOURCE+x}" || -n "${__SCRIPT_ARGS__+x}" || -n "${__SCRIPT_DIR__+x}" ]]; then
        printf '%s\n' "base_bash_libs_init: initialization names are already owned by the caller." >&2
        return 1
    fi

    __log_init__
    declare -g __color__=0
    declare -ga __std_cleanup_hooks=()
    declare -ga __std_cleanup_paths=()
    declare -ga __std_cleanup_entries=()
    declare -gA __std_cleanup_path_fingerprints=()
    declare -g __std_cleanup_dispatcher_installed=0
    declare -g __std_cleanup_dispatcher_running=0
    declare -g __std_cleanup_dispatcher_finished=0
    declare -g __std_cleanup_pending_signal_status=0
    declare -g __std_cleanup_debug_guard_running=0
    declare -g __std_original_exit_trap=""
    declare -g __std_original_exit_trap_spec=""
    declare -g __std_cleanup_dispatcher_trap_spec=""
    declare -g __std_original_int_trap=""
    declare -g __std_original_int_trap_spec=""
    declare -g __std_cleanup_int_trap_spec="__not-installed__"
    declare -g __std_original_term_trap=""
    declare -g __std_original_term_trap_spec=""
    declare -g __std_cleanup_term_trap_spec="__not-installed__"
    declare -g __std_original_debug_trap=""
    declare -g __std_original_debug_trap_spec=""
    declare -g __std_cleanup_debug_trap_spec="__not-installed__"

    readonly BASE_BASH_LIBS_STD_INIT_SOURCE="$script_dir"
    declare -ga __SCRIPT_ARGS__=("$@")
    readonly -a __SCRIPT_ARGS__
    declare -g __SCRIPT_DIR__="$script_dir"
    readonly __SCRIPT_DIR__
    readonly BASE_BASH_LIBS_STD_INITIALIZED=1
}

#
# base_bash_libs_init - Explicitly initializes runtime state and filters wrapper
# flags into a caller-owned indexed array. Sourcing the library never invokes
# this function and never mutates positional parameters.
#
# Usage:
#   declare -a app_args=()
#   base_bash_libs_init app_args --source "$script" -- "$@"
#
base_bash_libs_init() {
    local result_name="${1-}" source_path="" script_dir="" arg
    local parse_config=1 color_requested=0 configure_runtime=0
    local -a input_args=() filtered_args=()

    (($# >= 1)) || {
        printf '%s\n' "base_bash_libs_init: expected a result array name." >&2
        return 1
    }
    __std_init_validate_result_array__ "$result_name" || return 1
    shift

    while (($#)); do
        if ((parse_config)) && [[ "$1" == "--source" ]]; then
            (($# >= 2)) || {
                printf '%s\n' "base_bash_libs_init: --source requires a script path." >&2
                return 1
            }
            source_path="$2"
            shift 2
            continue
        fi
        if ((parse_config)) && [[ "$1" == "--" ]]; then
            parse_config=0
            shift
            input_args+=("$@")
            break
        fi
        input_args+=("$1")
        shift
    done

    source_path="${source_path:-${BASE_BASH_BOOTSTRAP_SOURCE:-${BASH_SOURCE[1]-}}}"
    if [[ -n "$source_path" ]]; then
        script_dir="$(cd -- "$(dirname -- "$source_path")" &>/dev/null && pwd -P)" || {
            printf '%s\n' "base_bash_libs_init: unable to resolve source directory from '$source_path'." >&2
            return 1
        }
    else
        script_dir="$(pwd -P)" || {
            printf '%s\n' "base_bash_libs_init: unable to resolve the current caller directory." >&2
            return 1
        }
    fi

    if [[ -n "${BASE_BASH_LIBS_STD_INITIALIZED+x}" ]]; then
        [[ "${BASE_BASH_LIBS_STD_INIT_SOURCE:-}" == "$script_dir" ]] || {
            printf '%s\n' "base_bash_libs_init: already initialized for '$BASE_BASH_LIBS_STD_INIT_SOURCE'; requested '$script_dir'." >&2
            return 1
        }
        __std_init_args_match__ "${input_args[@]+${input_args[@]}}" || {
            printf '%s\n' "base_bash_libs_init: repeated initialization received different argv; refusing to hide the mismatch." >&2
            return 1
        }
    else
        configure_runtime=1
        __std_initialize_runtime_state__ "$script_dir" "${input_args[@]+${input_args[@]}}" || return 1
    fi

    parse_config=1
    for arg in "${input_args[@]+${input_args[@]}}"; do
        if ((parse_config)) && [[ "$arg" == "--" ]]; then
            filtered_args+=("$arg")
            parse_config=0
            continue
        fi
        if ((parse_config)); then
            case "$arg" in
                --debug-wrapper)
                    if ((configure_runtime)); then
                        set_log_level DEBUG
                        set_log_category_level -l base_bash_libs DEBUG
                        export LOG_DEBUG=1
                    fi
                    ;;
                --verbose-wrapper)
                    if ((configure_runtime)); then
                        set_log_level VERBOSE
                        set_log_category_level -l base_bash_libs VERBOSE
                        export LOG_DEBUG=1
                    fi
                    ;;
                --utc-wrapper)
                    if ((configure_runtime)); then
                        export LOG_UTC=1
                    fi
                    ;;
                --color)
                    color_requested=1
                    ;;
                *)
                    filtered_args+=("$arg")
                    ;;
            esac
        else
            filtered_args+=("$arg")
        fi
    done

    if ((configure_runtime)); then
        __color__="$color_requested"
        __init_colors__
        set_log_category_level -l base_bash_libs INFO
        # Re-apply explicit debug levels after the default category gate.
        for arg in "${input_args[@]+${input_args[@]}}"; do
            if [[ "$arg" == "--debug-wrapper" ]]; then
                set_log_category_level -l base_bash_libs DEBUG
            elif [[ "$arg" == "--verbose-wrapper" ]]; then
                set_log_category_level -l base_bash_libs VERBOSE
            fi
        done
    fi

    __std_init_publish_array__ "$result_name" "${filtered_args[@]+${filtered_args[@]}}"
    return 0
}

################################################# LIBRARY IMPORTER #####################################################

#
# import - Sources one or more other library files.
#
# This function provides a robust way to include other shell libraries. It handles
# both absolute and relative paths. Relative paths are resolved from the directory
# of the main script that sourced this library.
#
# Usage:
#   import /path/to/absolute/lib.sh
#   import relative/path/to/lib2.sh
#
# IMPORTANT NOTE: If your library has global variables declared with 'declare',
# you must add the -g flag (e.g., `declare -gA my_map`). Since the library is
# sourced inside this function, globals declared without -g would become local
# to the function and be unavailable to other functions.
#
import() {
    local lib import_path
    for lib; do
        import_path="$lib"
        if [[ "$lib" != /* ]]; then
           [[ -n "${__SCRIPT_DIR__-}" ]] || { printf '%s\n' "ERROR: base_bash_libs_init must run before relative imports" >&2; exit 1; }
           import_path="$__SCRIPT_DIR__/$lib"
        fi
        if [[ -f "$import_path" ]]; then
            # shellcheck disable=SC1090
            source "$import_path"
            exit_if_error $? "Import of library '$lib' not successful."
        else
            exit_if_error 1 "Library '$lib' does not exist"
        fi
    done
    return 0
}

################################################# PATH MANIPULATION ####################################################

#
# add_to_path - Adds one or more directories to the system PATH.
#
# This function safely adds directories to the PATH, avoiding duplicates.
#
# Usage:
#   add_to_path [options] /path/to/dir1 /path/to/dir2 ...
#
# Options:
#   -p : Prepend the directory to the PATH instead of appending.
#   -n : Do not check if the directory exists before adding it.
#
add_to_path() {
    local dir path_dir prepend=0 opt strict=1 index in_path directory_count
    local -a path_dirs directories=()
    local OPTIND=1
    while getopts np opt; do
        case "$opt" in
            n)  strict=0  ;;  # don't care if directory exists or not before adding it to PATH
            p)  prepend=1 ;;  # prepend the directory to PATH instead of appending
            *)  log_error -l base_bash_libs.std "add_to_path: invalid option '$opt'"
                return 1
                ;;
        esac
    done

    shift $((OPTIND-1))

    directories=("$@")
    directory_count=$#
    if ((prepend)); then
        for ((index = directory_count - 1; index >= 0; index--)); do
            dir="${directories[index]}"
            ((strict)) && [[ ! -d $dir ]] && continue
            in_path=0
            IFS=: read -ra path_dirs <<< "$PATH"
            for path_dir in "${path_dirs[@]+"${path_dirs[@]}"}"; do
                if [[ "$path_dir" == "$dir" ]]; then
                    in_path=1
                    break
                fi
            done
            if ((! in_path)); then
                PATH="$dir:$PATH"
            fi
        done
    else
        for dir in "${directories[@]+"${directories[@]}"}"; do
            in_path=0
            ((strict)) && [[ ! -d $dir ]] && continue
            IFS=: read -ra path_dirs <<< "$PATH"
            for path_dir in "${path_dirs[@]+"${path_dirs[@]}"}"; do
                if [[ "$path_dir" == "$dir" ]]; then
                    in_path=1
                    break
                fi
            done
            if ((! in_path)); then
                PATH="$PATH:$dir"
            fi
        done
    fi

    # It's good practice to de-duplicate the path after adding to it
    dedupe_path
    return 0
}

#
# dedupe_path - Removes duplicate entries from the PATH variable.
#
dedupe_path() {
    local -A seen
    local IFS=':' new_path dir
    for dir in $PATH; do
        if [[ -n "$dir" && -z "${seen[$dir]-}" ]]; then
            new_path="${new_path:+$new_path:}$dir"
            seen["$dir"]=1
        fi
    done
    PATH="$new_path"
}

#
# print_path - Prints each directory in the PATH on a new line.
#
print_path() {
    local IFS=':' dirs dir
    IFS=: read -ra dirs <<< "$PATH"
    for dir in "${dirs[@]+"${dirs[@]}"}"; do printf '%s\n' "$dir"; done
}

#################################################### LOGGING ###########################################################

#
# __log_init__ - Initializes the logging system.
#
# Sets up colors for interactive terminals and defines the log level hierarchy.
# This is called by base_bash_libs_init.
#
__log_init__() {
    # Map log level strings (FATAL, ERROR, etc.) to numeric values.
    # Note the '-g' option passed to declare is essential for global scope.
    unset _log_levels _loggers_level_map _log_category_level_map _log_primary_sink_failed_paths
    declare -gA _log_levels _loggers_level_map _log_category_level_map _log_primary_sink_failed_paths
    _log_primary_sink_failed_paths=()
    # VERBOSE is deprecated compatibility surface; new callers should use DEBUG.
    _log_levels=([FATAL]=0 [ERROR]=1 [WARN]=2 [INFO]=3 [DEBUG]=4 [VERBOSE]=5)

    # Terminal output defaults to INFO. Category filtering is a separate,
    # permissive gate so existing callers retain their current sink behavior.
    _loggers_level_map["default"]=3
    _log_category_level_map["default"]=5
}

#
# __join_message__ - Join message fragments with a stable single-space separator.
#
__join_message__() {
    local __std_join_message_result="" __std_join_message_fragment __std_join_message_separator=""

    for __std_join_message_fragment in "$@"; do
        __std_join_message_result+="${__std_join_message_separator}${__std_join_message_fragment}"
        __std_join_message_separator=" "
    done
    printf '%s' "$__std_join_message_result"
}

#
# __log_timestamp__ - Store the current log timestamp in a named variable.
#
__log_timestamp__() {
    local __std_log_timestamp_result_name="$1"

    if [[ "${LOG_UTC:-}" == 1 ]]; then
        TZ=UTC0 printf -v "$__std_log_timestamp_result_name" '%(%Y-%m-%d %H:%M:%S)T UTC' -1
    else
        printf -v "$__std_log_timestamp_result_name" '%(%Y-%m-%d %H:%M:%S %z)T' -1
    fi
}

#
# __log_source_location__ - Store the first non-stdlib caller location.
#
__log_source_location__() {
    local __std_log_source_result_name="$1"
    local __std_log_source_fallback_path="${2:-}" __std_log_source_fallback_line="${3:-0}"
    local __std_log_source_path="" __std_log_source_line=""
    local __std_log_source_frame=1 __std_log_source_max_frames=20
    local __std_log_source_caller_info __std_log_source_caller_rest
    local __std_log_source_caller_line __std_log_source_caller_file

    while ((__std_log_source_frame <= __std_log_source_max_frames)) &&
        __std_log_source_caller_info=$(caller "$__std_log_source_frame"); do
        __std_log_source_caller_line="${__std_log_source_caller_info%% *}"
        __std_log_source_caller_rest="${__std_log_source_caller_info#* }"
        __std_log_source_caller_file="${__std_log_source_caller_rest#* }"
        if [[ -n "$__std_log_source_caller_file" &&
            "$__std_log_source_caller_file" != "$BASE_BASH_LIBS_STD_SOURCE_PATH" ]]; then
            __std_log_source_path="$__std_log_source_caller_file"
            __std_log_source_line="$__std_log_source_caller_line"
            break
        fi
        ((__std_log_source_frame++))
    done

    if [[ -z "$__std_log_source_path" ]]; then
        __std_log_source_path="${__std_log_source_fallback_path:-${BASH_SOURCE[2]:-${BASH_SOURCE[1]:-${BASH_SOURCE[0]:-unknown}}}}"
        __std_log_source_line="${__std_log_source_fallback_line:-${BASH_LINENO[1]:-${BASH_LINENO[0]:-0}}}"
    fi

    __std_log_source_path="${__std_log_source_path#"$__SCRIPT_DIR__"/}"
    __std_log_source_path="${__std_log_source_path#./}"
    printf -v "$__std_log_source_result_name" '%s:%s' "$__std_log_source_path" "$__std_log_source_line"
}

#
# __log_primary_sink_is_usable__ - Check the primary sink without modifying it.
#
__log_primary_sink_is_usable__() {
    local __std_log_primary_usable_path="${1-}" __std_log_primary_usable_parent_dir

    [[ -n "$__std_log_primary_usable_path" && "$__std_log_primary_usable_path" != */ ]] || return 1
    [[ -z "${_log_primary_sink_failed_paths[$__std_log_primary_usable_path]+set}" ]] || return 1
    [[ ! -L "$__std_log_primary_usable_path" ]] || return 1

    if [[ -e "$__std_log_primary_usable_path" ]]; then
        if [[ -f "$__std_log_primary_usable_path" && -O "$__std_log_primary_usable_path" &&
            -w "$__std_log_primary_usable_path" ]]; then
            return 0
        fi
        return 1
    fi

    if [[ "$__std_log_primary_usable_path" == */* ]]; then
        __std_log_primary_usable_parent_dir="${__std_log_primary_usable_path%/*}"
        [[ -n "$__std_log_primary_usable_parent_dir" ]] || __std_log_primary_usable_parent_dir=/
    else
        __std_log_primary_usable_parent_dir=.
    fi

    [[ -d "$__std_log_primary_usable_parent_dir" && -w "$__std_log_primary_usable_parent_dir" &&
        -x "$__std_log_primary_usable_parent_dir" ]]
}

#
# __log_primary_sink_prepare__ - Create or privately harden a usable sink.
#
__log_primary_sink_prepare__() {
    local __std_log_primary_prepare_path="$1" __std_log_primary_prepare_chmod_path

    __log_primary_sink_is_usable__ "$__std_log_primary_prepare_path" || return 1

    if [[ ! -e "$__std_log_primary_prepare_path" ]]; then
        # noclobber avoids truncating a target that appears after the
        # non-mutating eligibility check.
        if ! (umask 077; set -o noclobber; : >"$__std_log_primary_prepare_path") 2>/dev/null; then
            [[ -e "$__std_log_primary_prepare_path" && ! -L "$__std_log_primary_prepare_path" ]] || return 1
        fi
    fi

    [[ -f "$__std_log_primary_prepare_path" && ! -L "$__std_log_primary_prepare_path" &&
        -O "$__std_log_primary_prepare_path" && -w "$__std_log_primary_prepare_path" ]] || return 1

    # macOS chmod does not accept "--"; prefix a bare option-like path instead.
    __std_log_primary_prepare_chmod_path="$__std_log_primary_prepare_path"
    [[ "$__std_log_primary_prepare_chmod_path" == -* ]] &&
        __std_log_primary_prepare_chmod_path="./$__std_log_primary_prepare_chmod_path"
    command chmod 600 "$__std_log_primary_prepare_chmod_path" 2>/dev/null || return 1

    [[ -f "$__std_log_primary_prepare_path" && ! -L "$__std_log_primary_prepare_path" &&
        -O "$__std_log_primary_prepare_path" && -w "$__std_log_primary_prepare_path" ]]
}

#
# __log_primary_sink_append__ - Append one record or file payload.
#
__log_primary_sink_append__() {
    local __std_log_primary_append_kind="${1-}" __std_log_primary_append_payload="${2-}"
    local __std_log_primary_append_path="${BASE_CLI_PRIMARY_LOG:-}"

    __log_primary_sink_is_usable__ "$__std_log_primary_append_path" || return 1

    (
        umask 077
        __log_primary_sink_prepare__ "$__std_log_primary_append_path" || exit 1

        case "$__std_log_primary_append_kind" in
            record)
                printf '%s\n' "$__std_log_primary_append_payload"
                ;;
            file)
                command cat -- "$__std_log_primary_append_payload" || exit 1
                printf '\n'
                ;;
            *)
                exit 1
                ;;
        esac >>"$__std_log_primary_append_path"
    ) 2>/dev/null
}

#
# __log_primary_sink_write__ - Keep sink failures best-effort and disable them.
#
__log_primary_sink_write__() {
    local __std_log_primary_write_kind="$1" __std_log_primary_write_payload="$2"
    local __std_log_primary_write_path="${BASE_CLI_PRIMARY_LOG:-}"

    if ! __log_primary_sink_append__ "$__std_log_primary_write_kind" "$__std_log_primary_write_payload"; then
        _log_primary_sink_failed_paths["$__std_log_primary_write_path"]=1
    fi
    return 0
}

#
# __print_log_record__ - Compose and write a structured log record.
#
__print_log_record__() {
    local __std_log_record_color="$1" __std_log_record_level="$2" __std_log_record_source="$3"
    local __std_log_record_terminal_enabled="${4:-1}" __std_log_record_persist_enabled="${5:-0}"
    shift 5
    local __std_log_record_message __std_log_record_timestamp __std_log_record_line

    __std_log_record_message="$(__join_message__ "$@")"
    __log_timestamp__ __std_log_record_timestamp
    printf -v __std_log_record_line '%s %-7s %s %s' \
        "$__std_log_record_timestamp" "$__std_log_record_level" "$__std_log_record_source" \
        "$__std_log_record_message"
    if ((__std_log_record_terminal_enabled)); then
        printf '%b%s%b\n' "$__std_log_record_color" "$__std_log_record_line" "$COLOR_OFF" >&2
    fi
    if ((__std_log_record_persist_enabled)); then
        __log_primary_sink_write__ record "$__std_log_record_line"
    fi
}

#
# __init_colors__ - Initialize colors used for logging
# This is called from base_bash_libs_init.
#
__init_colors__() {
    # If --color was not passed, NO_COLOR is set, or the log stream is not a terminal, disable colors.
    if [[ "$__color__" != 1 || -n "${NO_COLOR+x}" || ! -t 2 ]]; then
        COLOR_BOLD=""
        COLOR_RED=""
        COLOR_GREEN=""
        COLOR_YELLOW=""
        COLOR_BLUE=""
        COLOR_OFF=""
    else
        # colors for logging in interactive mode
        COLOR_BOLD="\033[1m"
        COLOR_RED="\033[0;31m"
        COLOR_GREEN="\033[0;32m"
        COLOR_YELLOW="\033[0;33m"
        COLOR_BLUE="\033[0;36m"
        COLOR_OFF="\033[0m"
    fi
    readonly COLOR_BOLD COLOR_RED COLOR_GREEN COLOR_YELLOW COLOR_BLUE COLOR_OFF
}

#
# set_log_level - Sets the logging verbosity for a given logger.
#
# Usage:
#   set_log_level [level]
#   set_log_level -l [logger_name] [level]
#
# Arguments:
#   level: One of FATAL, ERROR, WARN, INFO, DEBUG, VERBOSE. Default is INFO.
#   -l logger_name: (Optional) Specify a named logger. Default is 'default'.
# Invalid levels return 1 and leave the existing logger level unchanged.
#
set_log_level() {
    local __std_set_log_logger=default __std_set_log_level __std_set_log_level_value
    local __std_set_log_source_location
    if [[ "${1-}" == "-l" ]]; then
        if [[ -z "${2-}" ]]; then
            __log_source_location__ __std_set_log_source_location \
                "${BASH_SOURCE[1]:-${0:-unknown}}" "${BASH_LINENO[0]:-0}"
            printf '%(%Y-%m-%d:%H:%M:%S)T %-7s %s\n' -1 WARN \
                "$__std_set_log_source_location Option '-l' needs an argument" >&2
            return 1
        fi
        __std_set_log_logger=$2
        shift 2 2>/dev/null
    fi
    __std_set_log_level="${1:-INFO}"
    if [[ -z "$__std_set_log_logger" ]]; then
        __log_source_location__ __std_set_log_source_location \
            "${BASH_SOURCE[1]:-${0:-unknown}}" "${BASH_LINENO[0]:-0}"
        printf '%(%Y-%m-%d:%H:%M:%S)T %-7s %s\n' -1 WARN \
            "$__std_set_log_source_location Option '-l' needs an argument" >&2
        return 1
    fi

    if [[ -n "${_log_levels[$__std_set_log_level]+set}" ]]; then
        __std_set_log_level_value="${_log_levels[$__std_set_log_level]}"
        _loggers_level_map[$__std_set_log_logger]=$__std_set_log_level_value
        return 0
    fi

    __log_source_location__ __std_set_log_source_location \
        "${BASH_SOURCE[1]:-${0:-unknown}}" "${BASH_LINENO[0]:-0}"
    printf '%(%Y-%m-%d:%H:%M:%S)T %-7s %s\n' -1 WARN \
        "$__std_set_log_source_location Unknown log level '$__std_set_log_level' for logger '$__std_set_log_logger'" >&2
    return 1
}

#
# set_log_category_level - Sets the gate for a hierarchical log category.
#
# Usage:
#   set_log_category_level -l [category] [level]
#
# Categories inherit by dotted parent name. For example, base.git.fetch first
# checks base.git.fetch, then base.git, then base, and finally default.
# Invalid arguments return 1 without changing the existing category level.
#
set_log_category_level() {
    local __std_set_category_name __std_set_category_level __std_set_category_level_value
    local __std_set_category_source_location

    if [[ "$#" -ne 3 || "${1-}" != "-l" || -z "${2-}" || -z "${3-}" ]]; then
        __log_source_location__ __std_set_category_source_location \
            "${BASH_SOURCE[1]:-${0:-unknown}}" "${BASH_LINENO[0]:-0}"
        printf '%(%Y-%m-%d:%H:%M:%S)T %-7s %s\n' -1 WARN \
            "$__std_set_category_source_location Usage: set_log_category_level -l <category> <level>" >&2
        return 1
    fi

    __std_set_category_name=$2
    __std_set_category_level=$3
    if [[ -n "${_log_levels[$__std_set_category_level]+set}" ]]; then
        __std_set_category_level_value="${_log_levels[$__std_set_category_level]}"
        _log_category_level_map[$__std_set_category_name]=$__std_set_category_level_value
        return 0
    fi

    __log_source_location__ __std_set_category_source_location \
        "${BASH_SOURCE[1]:-${0:-unknown}}" "${BASH_LINENO[0]:-0}"
    printf '%(%Y-%m-%d:%H:%M:%S)T %-7s %s\n' -1 WARN \
        "$__std_set_category_source_location Unknown log level '$__std_set_category_level' for category '$__std_set_category_name'" >&2
    return 1
}

#
# __resolve_log_category_level__ - Resolve a category through its dotted parents.
#
__resolve_log_category_level__() {
    local __std_log_category_result_name="$1" __std_log_category_name="${2:-default}"
    local __std_log_category_candidate

    __std_log_category_candidate=$__std_log_category_name
    while [[ -n "$__std_log_category_candidate" ]]; do
        if [[ -n "${_log_category_level_map[$__std_log_category_candidate]+set}" ]]; then
            printf -v "$__std_log_category_result_name" '%s' \
                "${_log_category_level_map[$__std_log_category_candidate]}"
            return 0
        fi
        [[ "$__std_log_category_candidate" == *.* ]] || break
        __std_log_category_candidate="${__std_log_category_candidate%.*}"
    done

    printf -v "$__std_log_category_result_name" '%s' "${_log_category_level_map[default]}"
}

#
# __log_sink_state__ - Store terminal and persistent-sink decisions.
#
__log_sink_state__() {
    local __std_log_sink_category="$1" __std_log_sink_level="$2"
    local __std_log_sink_terminal_result="$3" __std_log_sink_persist_result="$4"
    local __std_log_sink_event_level __std_log_sink_category_level __std_log_sink_terminal_level
    local __std_log_sink_terminal_state=0 __std_log_sink_persist_state=0

    [[ -n "${_log_levels[$__std_log_sink_level]+set}" ]] || return 1
    __std_log_sink_event_level="${_log_levels[$__std_log_sink_level]}"
    __resolve_log_category_level__ __std_log_sink_category_level "$__std_log_sink_category"

    if ((__std_log_sink_category_level >= __std_log_sink_event_level)); then
        __std_log_sink_terminal_level="${_loggers_level_map[$__std_log_sink_category]:-${_loggers_level_map[default]}}"
        ((__std_log_sink_terminal_level >= __std_log_sink_event_level)) && __std_log_sink_terminal_state=1
        if ((__std_log_sink_event_level <= _log_levels[DEBUG])) &&
            __log_primary_sink_is_usable__ "${BASE_CLI_PRIMARY_LOG:-}"; then
            __std_log_sink_persist_state=1
        fi
    fi

    printf -v "$__std_log_sink_terminal_result" '%s' "$__std_log_sink_terminal_state"
    printf -v "$__std_log_sink_persist_result" '%s' "$__std_log_sink_persist_state"
}

#
# log_is_enabled - Return success when any configured sink accepts a level.
#
# Usage:
#   log_is_enabled [-l category] level
#
log_is_enabled() {
    local __std_log_enabled_category=default __std_log_enabled_level
    local __std_log_enabled_terminal __std_log_enabled_persist __std_log_enabled_source_location

    if [[ "${1-}" == "-l" ]]; then
        if [[ -z "${2-}" ]]; then
            __log_source_location__ __std_log_enabled_source_location \
                "${BASH_SOURCE[1]:-${0:-unknown}}" "${BASH_LINENO[0]:-0}"
            printf '%(%Y-%m-%d:%H:%M:%S)T %-7s %s\n' -1 WARN \
                "$__std_log_enabled_source_location Option '-l' needs an argument" >&2
            return 1
        fi
        __std_log_enabled_category=$2
        shift 2
    fi
    if [[ "$#" -ne 1 || -z "${1-}" ]]; then
        __log_source_location__ __std_log_enabled_source_location \
            "${BASH_SOURCE[1]:-${0:-unknown}}" "${BASH_LINENO[0]:-0}"
        printf '%(%Y-%m-%d:%H:%M:%S)T %-7s %s\n' -1 WARN \
            "$__std_log_enabled_source_location Usage: log_is_enabled [-l <category>] <level>" >&2
        return 1
    fi
    __std_log_enabled_level=$1
    if [[ -z "${_log_levels[$__std_log_enabled_level]+set}" ]]; then
        __log_source_location__ __std_log_enabled_source_location \
            "${BASH_SOURCE[1]:-${0:-unknown}}" "${BASH_LINENO[0]:-0}"
        printf '%(%Y-%m-%d:%H:%M:%S)T %-7s %s\n' -1 WARN \
            "$__std_log_enabled_source_location Unknown log level '$__std_log_enabled_level' for category '$__std_log_enabled_category'" >&2
        return 1
    fi

    __log_sink_state__ "$__std_log_enabled_category" "$__std_log_enabled_level" \
        __std_log_enabled_terminal __std_log_enabled_persist || return 1
    ((__std_log_enabled_terminal || __std_log_enabled_persist))
}

#
# __print_log__ - Core and private log printing logic.
#
# This is the internal engine for the logging functions. It formats the log
# message with a timestamp, log level, and source location. It should not
# be called directly; use the `log_*` helper functions instead.
#
__print_log__() {
    local __std_print_log_level="${1-}"
    [[ -n "$__std_print_log_level" ]] || return 1
    shift
    local __std_print_log_logger=default __std_print_log_color __std_print_log_source_location
    local __std_print_log_terminal_enabled __std_print_log_persist_enabled
    if [[ "${1-}" == "-l" ]]; then
        if [[ -z "${2-}" ]]; then
            __log_source_location__ __std_print_log_source_location \
                "${BASH_SOURCE[1]:-${0:-unknown}}" "${BASH_LINENO[0]:-0}"
            printf '%(%Y-%m-%d %H:%M:%S)T %s\n' -1 \
                "WARN $__std_print_log_source_location Option '-l' needs an argument" >&2
            return 1
        fi
        __std_print_log_logger=$2
        shift 2
    fi
    __log_sink_state__ "$__std_print_log_logger" "$__std_print_log_level" \
        __std_print_log_terminal_enabled __std_print_log_persist_enabled || return 1

    if ((__std_print_log_terminal_enabled || __std_print_log_persist_enabled)); then
        # Select color based on log level
        case "$__std_print_log_level" in
            FATAL|ERROR) __std_print_log_color="$COLOR_RED";;
            WARN)        __std_print_log_color="$COLOR_YELLOW";;
            INFO)        __std_print_log_color="$COLOR_GREEN";;
            DEBUG)       __std_print_log_color="$COLOR_BLUE";;
            *)           __std_print_log_color="";; # No color for VERBOSE or others
        esac

        __log_source_location__ __std_print_log_source_location \
            "${BASH_SOURCE[2]:-}" "${BASH_LINENO[1]:-0}"
        __print_log_record__ "$__std_print_log_color" "$__std_print_log_level" \
            "$__std_print_log_source_location" "$__std_print_log_terminal_enabled" \
            "$__std_print_log_persist_enabled" "$@"
    fi
}

#
# __print_log_file__ - Core function for logging the contents of a file.
#
# Internal helper to be called by `log_info_file`, etc.
#
__print_log_file__()   {
    local __std_print_file_level="${1-}"
    [[ -n "$__std_print_file_level" ]] || return 1
    shift
    local __std_print_file_logger=default __std_print_file_path __std_print_file_source_location
    local __std_print_file_terminal_enabled __std_print_file_persist_enabled
    if [[ "${1-}" == "-l" ]]; then
        if [[ -z "${2-}" ]]; then
            __log_source_location__ __std_print_file_source_location \
                "${BASH_SOURCE[1]:-${0:-unknown}}" "${BASH_LINENO[0]:-0}"
            printf '%(%Y-%m-%d %H:%M:%S)T %s\n' -1 \
                "WARN $__std_print_file_source_location Option '-l' needs an argument" >&2
            return 1
        fi
        __std_print_file_logger=$2
        shift 2
    fi
    __std_print_file_path="${1-}"
    __log_sink_state__ "$__std_print_file_logger" "$__std_print_file_level" \
        __std_print_file_terminal_enabled __std_print_file_persist_enabled || return 1
    if ((__std_print_file_terminal_enabled || __std_print_file_persist_enabled)) &&
        [[ -f "$__std_print_file_path" ]]; then
        __print_log__ "$__std_print_file_level" -l "$__std_print_file_logger" \
            "Contents of file '$__std_print_file_path':"
        if ((__std_print_file_terminal_enabled)); then
            cat -- "$__std_print_file_path" >&2
            # Keep the next structured record separate even when the file does
            # not end in a newline. A blank separator is harmless otherwise.
            printf '\n' >&2
        fi
        if ((__std_print_file_persist_enabled)); then
            __log_primary_sink_write__ file "$__std_print_file_path"
        fi
    fi
}

#
# Public logging functions.
# These are the primary functions scripts should use for logging.
#
log_fatal()   { __print_log__ FATAL   "$@"; }
log_error()   { __print_log__ ERROR   "$@"; }
log_warn()    { __print_log__ WARN    "$@"; }
log_info()    { __print_log__ INFO    "$@"; }
log_debug()   { __print_log__ DEBUG   "$@"; }
# Deprecated compatibility helper; prefer log_debug.
log_verbose() { __print_log__ VERBOSE "$@"; }

#
# Public functions for logging the content of a file.
#
log_info_file()    { __print_log_file__ INFO    "$@"; }
log_debug_file()   { __print_log_file__ DEBUG   "$@"; }
# Deprecated compatibility helper; prefer log_debug_file.
log_verbose_file() { __print_log_file__ VERBOSE "$@"; }

#
# Public functions for logging function entry and exit points.
#
log_info_enter()    { __print_log__ INFO    "Entering function ${FUNCNAME[1]:-main}"; }
log_debug_enter()   { __print_log__ DEBUG   "Entering function ${FUNCNAME[1]:-main}"; }
# Deprecated compatibility helper; prefer log_debug_enter.
log_verbose_enter() { __print_log__ VERBOSE "Entering function ${FUNCNAME[1]:-main}"; }
log_info_leave()    { __print_log__ INFO    "Leaving function ${FUNCNAME[1]:-main}";  }
log_debug_leave()   { __print_log__ DEBUG   "Leaving function ${FUNCNAME[1]:-main}";  }
# Deprecated compatibility helper; prefer log_debug_leave.
log_verbose_leave() { __print_log__ VERBOSE "Leaving function ${FUNCNAME[1]:-main}";  }

#
# Simple print routines that do not prefix messages with timestamps or levels.
#
print_error()   { local __std_print_error_message; __std_print_error_message="$(__join_message__ "$@")"; { printf '%bERROR: %s%b\n' "$COLOR_RED" "$__std_print_error_message" "$COLOR_OFF"; } >&2; }
print_warn()    { local __std_print_warn_message; __std_print_warn_message="$(__join_message__ "$@")"; { printf '%bWARN: %s%b\n' "$COLOR_YELLOW" "$__std_print_warn_message" "$COLOR_OFF"; } >&2; }
print_info()    { local __std_print_info_message; __std_print_info_message="$(__join_message__ "$@")"; { printf '%b%s%b\n' "$COLOR_GREEN" "$__std_print_info_message" "$COLOR_OFF"; } >&2; }
print_success() { local __std_print_success_message; __std_print_success_message="$(__join_message__ "$@")"; { printf '%bSUCCESS: %s%b\n' "$COLOR_GREEN" "$__std_print_success_message" "$COLOR_OFF"; } >&2; }
print_bold()    { local __std_print_bold_message; __std_print_bold_message="$(__join_message__ "$@")"; printf '%b%s%b\n' "$COLOR_BOLD" "$__std_print_bold_message" "$COLOR_OFF"; }
print_message() { printf '%s\n' "$@"; }

#
# print_tty - Prints a message only if the output is going to a terminal.
#
print_tty() {
    if [[ -t 1 ]]; then
        printf '%s\n' "$(__join_message__ "$@")"
    fi
}

################################################## ERROR HANDLING ######################################################

#
# dump_trace - Prints a stack trace of the Bash function calls.
#
# This is useful for debugging to see the sequence of function calls
# that led to an error.
#
dump_trace() {
    local __std_trace_frame=0 __std_trace_line __std_trace_func __std_trace_source __std_trace_caller_info
    while __std_trace_caller_info="$(caller "$__std_trace_frame")"; do
        IFS=' ' read -r __std_trace_line __std_trace_func __std_trace_source <<<"$__std_trace_caller_info"
        if ((__std_trace_frame == 0)); then
            printf 'Encountered a fatal error\n'
        fi
        printf '%4s at %s\n' " " "$__std_trace_func ($__std_trace_source:$__std_trace_line)"
        ((__std_trace_frame += 1))
    done >&2
    return 0
}

#
# exit_if_error - Exits the script if the provided exit code is non-zero.
#
# This is the primary error handling function. It checks a command's exit
# code and, if it indicates failure, logs a fatal message, dumps a stack
# trace, and exits the script.
#
# Usage:
#   command_that_might_fail
#   exit_if_error $? "A descriptive error message."
#
# Arguments:
#   $1: The exit code to check (typically $?).
#   $@: The error message to log if the exit code is non-zero.
#
exit_if_error() {
    (($#)) || return
    local __std_exit_number_re='^[0-9]+$'
    local __std_exit_status=$1 __std_exit_normalized_status
    shift
    local __std_exit_message
    if (($#)); then
        __std_exit_message="$(__join_message__ "$@")"
    else
        __std_exit_message="No message specified"
    fi
    if ! [[ $__std_exit_status =~ $__std_exit_number_re ]]; then
        log_error -l base_bash_libs.std \
            "'$__std_exit_status' is not a valid exit code; it needs to be a number greater than zero. Treating it as 1."
        __std_exit_status=1
    elif ! __std_decimal_integer_value__ __std_exit_normalized_status "$__std_exit_status"; then
        log_error -l base_bash_libs.std "'$__std_exit_status' is not a valid decimal exit code. Treating it as 1."
        __std_exit_status=1
    else
        __std_exit_status="$__std_exit_normalized_status"
    fi
    ((__std_exit_status)) && {
        log_fatal -l base_bash_libs.std "$__std_exit_message"
        dump_trace
        exit "$__std_exit_status"
    }
    return 0
}

#
# fatal_error - A convenience wrapper around exit_if_error.
#
# This function immediately triggers a fatal error, using the exit code
# of the last command if it was non-zero, or 1 otherwise.
#
# Usage:
#   [[ -f "$my_file" ]] || fatal_error "Required file '$my_file' not found."
#
fatal_error() {
    local __std_fatal_status=$?                         # grab the current exit code
    ((__std_fatal_status == 0)) && __std_fatal_status=1 # if it is zero, set exit code to 1
    exit_if_error "$__std_fatal_status" "$@"
}

#################################################### COMMAND EXECUTION #################################################

#
# is_dry_run - Returns true when dry-run mode is enabled.
#
# Dry-run mode may be enabled through either DRY_RUN or dry_run. Both names
# accept common truthy values so callers do not need to duplicate normalization.
#
is_dry_run() {
    local __std_dry_run_value

    for __std_dry_run_value in "${DRY_RUN-}" "${dry_run-}"; do
        case "${__std_dry_run_value,,}" in
            true | 1 | yes | on)
                return 0
                ;;
        esac
    done
    return 1
}

__std_decimal_integer_value__() {
    local __std_decimal_result_name="${1-}" __std_decimal_value="${2-}" __std_decimal_sign=""
    local __std_decimal_digits

    [[ "$__std_decimal_value" =~ ^[-+]?[0-9]+$ ]] || return 1
    case "$__std_decimal_value" in
        -*)
            __std_decimal_sign="-"
            __std_decimal_digits="${__std_decimal_value#-}"
            ;;
        +*)
            __std_decimal_digits="${__std_decimal_value#+}"
            ;;
        *)
            __std_decimal_digits="$__std_decimal_value"
            ;;
    esac

    while [[ "${#__std_decimal_digits}" -gt 1 && "${__std_decimal_digits:0:1}" == "0" ]]; do
        __std_decimal_digits="${__std_decimal_digits:1}"
    done

    if [[ "$__std_decimal_sign" == "-" && "$__std_decimal_digits" != "0" ]]; then
        printf -v "$__std_decimal_result_name" '%s' "-$((10#$__std_decimal_digits))"
    else
        printf -v "$__std_decimal_result_name" '%s' "$((10#$__std_decimal_digits))"
    fi
}

__std_is_positive_integer__() {
    local __std_positive_normalized
    __std_decimal_integer_value__ __std_positive_normalized "${1-}" || return 1
    ((__std_positive_normalized > 0))
}

__std_is_non_negative_integer__() {
    local __std_non_negative_normalized
    __std_decimal_integer_value__ __std_non_negative_normalized "${1-}" || return 1
    ((__std_non_negative_normalized >= 0))
}

__std_is_safe_display__() {
    (($# == 1)) || return 1

    local __std_safe_display_value="${1-}"
    local __std_safe_display_allowed_ascii
    local __std_safe_display_character __std_safe_display_index

    # Spell out the printable ASCII set instead of changing LC_ALL. Bash
    # variables use dynamic scope, so even a function-local locale binding can
    # collide with a caller's readonly LC_ALL. Quoted substring membership is
    # independent of character classes and locale collation.
    __std_safe_display_allowed_ascii=$' !"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~'

    [[ -n "$__std_safe_display_value" && "$__std_safe_display_value" != -* ]] || return 1
    for ((__std_safe_display_index = 0;
        __std_safe_display_index < ${#__std_safe_display_value};
        __std_safe_display_index++)); do
        __std_safe_display_character="${__std_safe_display_value:__std_safe_display_index:1}"
        [[ "$__std_safe_display_allowed_ascii" == *"$__std_safe_display_character"* ]] || return 1
    done
}

__std_render_command_display__() {
    (($# >= 4)) || return 1

    local __std_render_display_result_name="${1-}"
    local __std_render_display_sensitive="${2-}"
    local __std_render_display_safe_value="${3-}"
    local __std_render_display_protected_description="${4-}"
    local __std_render_display_value=""
    shift 4

    case "$__std_render_display_sensitive" in
        1)
            if [[ -n "$__std_render_display_safe_value" ]]; then
                __std_is_safe_display__ "$__std_render_display_safe_value" || return 1
                __std_render_display_value="$__std_render_display_safe_value $__std_render_display_protected_description"
            else
                __std_render_display_value="$__std_render_display_protected_description"
            fi
            ;;
        0)
            if (($#)); then
                printf -v __std_render_display_value '%q ' "$@"
                __std_render_display_value="${__std_render_display_value% }"
            fi
            ;;
        *)
            return 1
            ;;
    esac

    printf -v "$__std_render_display_result_name" '%s' "$__std_render_display_value"
}

__std_join_run_policy__() {
    local result_name="$1" timeout_seconds="$2" max_attempts="$3" retry_delay="$4"
    local policies=()
    local policy joined_policy=""

    [[ -n "$timeout_seconds" ]] && policies+=("${timeout_seconds}s timeout")
    ((max_attempts > 1)) && policies+=("${max_attempts} attempts")
    ((retry_delay > 0)) && policies+=("${retry_delay}s retry delay")

    for policy in "${policies[@]+"${policies[@]}"}"; do
        if [[ -n "$joined_policy" ]]; then
            joined_policy+=", "
        fi
        joined_policy+="$policy"
    done

    printf -v "$result_name" '%s' "$joined_policy"
}

__std_emit_dry_run_plan__() {
    local __std_dry_run_plan_message="${1-}"
    local __std_dry_run_plan_source __std_dry_run_plan_timestamp
    local __std_dry_run_plan_record __std_dry_run_plan_status=0

    # A dry-run plan is a safety control, not an ordinary informational log.
    # Write it directly to stderr so logger and category thresholds cannot hide
    # it. The same already-redacted record is copied to the optional primary
    # log on a best-effort basis.
    __log_source_location__ __std_dry_run_plan_source \
        "${BASH_SOURCE[2]:-}" "${BASH_LINENO[1]:-0}"
    __log_timestamp__ __std_dry_run_plan_timestamp
    builtin printf -v __std_dry_run_plan_record '%s %-7s %s %s' \
        "$__std_dry_run_plan_timestamp" "DRY-RUN" \
        "$__std_dry_run_plan_source" "$__std_dry_run_plan_message"
    builtin printf '%s\n' "$__std_dry_run_plan_record" >&2 ||
        __std_dry_run_plan_status=1
    if __log_primary_sink_is_usable__ "${BASE_CLI_PRIMARY_LOG:-}"; then
        __log_primary_sink_write__ record "$__std_dry_run_plan_record"
    fi
    return "$__std_dry_run_plan_status"
}

__std_run_once__() {
    local __std_run_once_outcome_result_name="$1"
    local __std_run_once_timeout_seconds="$2" __std_run_once_timeout_path="$3"
    # These mutable locals shadow the caller's authoritative state while a
    # shell-function command runs in Bash's dynamic scope. Assignments made by
    # the command are absorbed here and discarded when this helper returns.
    local __std_run_attempt_number="$4"
    local __std_run_once_outcome=command __std_run_once_status=0
    # shellcheck disable=SC2034 # Deliberate dynamic-scope collision shields.
    local __std_run_immutable_command_display
    # shellcheck disable=SC2034 # Deliberate dynamic-scope collision shields.
    local __std_run_policy_exit_on_failure __std_run_policy_quiet
    # shellcheck disable=SC2034 # Deliberate dynamic-scope collision shields.
    local __std_run_policy_timeout_seconds __std_run_policy_timeout_path
    # shellcheck disable=SC2034 # Deliberate dynamic-scope collision shields.
    local __std_run_policy_max_attempts __std_run_policy_retry_delay
    # shellcheck disable=SC2034 # Deliberate dynamic-scope collision shields.
    local __std_run_exit_code __std_run_message
    shift 4

    if [[ -n "$__std_run_once_timeout_seconds" ]]; then
        if __std_run_with_timeout_supervisor__ __std_run_once_outcome \
            "$__std_run_once_timeout_seconds" \
            "$__std_run_once_timeout_path" "$@"; then
            __std_run_once_status=0
        else
            __std_run_once_status=$?
        fi
    else
        if "$@"; then
            __std_run_once_status=0
        else
            __std_run_once_status=$?
        fi
    fi

    printf -v "$__std_run_once_outcome_result_name" '%s' \
        "$__std_run_once_outcome"
    return "$__std_run_once_status"
}

__std_run_status_message__() {
    local result_name="$1" exit_code="$2" timeout_seconds="$3"
    local outcome="$4" printable_command="$5"

    if [[ "$outcome" == timeout && -n "$timeout_seconds" ]]; then
        printf -v "$result_name" 'Command timed out after %ss: %s' "$timeout_seconds" "$printable_command"
    elif [[ "$outcome" == infrastructure ]]; then
        printf -v "$result_name" 'Command could not be supervised safely (exit %s): %s' "$exit_code" "$printable_command"
    else
        printf -v "$result_name" 'Command failed (exit %s): %s' "$exit_code" "$printable_command"
    fi
}

#
# std_run - Safely executes a simple command with its arguments.
#
# This function is designed to be a secure and robust replacement for using
# `eval` or simple command execution. It correctly handles arguments with
# spaces and special characters.
#
# Features:
#   - Secure: Does not use `eval`, preventing arbitrary code execution.
#   - Argument Safe: Correctly handles spaces and special characters in arguments.
#   - Dry-Run Mode: If the global variable DRY_RUN (or dry_run) is truthy, it
#     prints the command instead of running it.
#   - Optional Timeout: `--timeout N` bounds each command attempt to N seconds.
#   - Optional Retry: `--max-attempts N` retries failed commands up to N total
#     attempts, optionally sleeping `--retry-delay N` seconds between attempts.
#   - Exit on Failure: By default, it will exit the script if the command
#     returns a non-zero exit code.
#   - Optional No-Exit: If an initial argument is `--no-exit`, the function
#     will not exit on failure, allowing the calling script to handle the error.
#   - Optional Quiet Probe: If an initial argument is `--quiet`, handled
#     failures do not log warnings. This is intended for expected probe
#     failures and is most useful with `--no-exit`.
#   - Protected Diagnostics: `--sensitive` prevents framework-generated
#     diagnostics from rendering the command arguments. `--safe-display`
#     supplies an optional caller-vetted, single-line operation label.
#
# Usage:
#   std_run [options] command [arg1] [arg2] ...
#   std_run --sensitive [--safe-display label] [options] -- command [arg1] ...
#
# Options:
#   --no-exit   If provided as an initial argument, the script will not
#               exit if the command fails. The function will return the
#               command's original exit code.
#   --quiet     If provided as an initial argument with `--no-exit`, suppress
#               the warning normally logged when the command fails.
#   --timeout N
#               Bound each command attempt to N seconds.
#   --max-attempts N
#               Try the command up to N total times. Defaults to 1.
#   --retry-attempts N
#               Alias for --max-attempts.
#   --retry-delay N
#               Sleep N seconds between failed attempts. Defaults to 0.
#   --sensitive  Hide the command and all arguments from framework-generated
#               dry-run, retry, timeout, and final-failure diagnostics. A
#               literal `--` must separate runner options from the command.
#   --safe-display LABEL
#               Add a printable ASCII operation label that is non-empty and
#               does not begin with `-`. Valid only with `--sensitive`.
#
# Examples:
#   # Run a simple command. Exits if `ls` fails.
#   std_run ls -l /tmp
#
#   # Run a command with spaces in an argument.
#   std_run touch "a file with spaces.txt"
#
#   # Run a command but don't exit the script on failure.
#   if ! std_run --no-exit grep "not_found" /etc/hosts; then
#       log "INFO" "The text was not found, but we are continuing."
#   fi
#
#   # In a script where DRY_RUN=true, this will only print the command.
#   DRY_RUN=true
#   std_run rm -rf /some/important/path
#
#   # Protect credentials in framework-generated diagnostics.
#   std_run --sensitive --safe-display "upload release asset" -- \
#       curl -H "Authorization: Bearer $token" "$upload_url"
#
################################################################################
__std_run_impl__() {
    local helper_name="$1"
    shift
    local exit_on_failure=1 quiet=0 timeout_seconds="" timeout_path="" max_attempts=1 retry_delay=0
    local sensitive=0 safe_display="" safe_display_set=0 option_terminator_seen=0

    # Parse optional run flags before the command.
    while (($#)); do
        case "${1-}" in
            --no-exit)
                exit_on_failure=0
                shift
                ;;
            --quiet)
                quiet=1
                shift
                ;;
            --timeout)
                shift
                if (($# == 0)) || ! __std_is_positive_integer__ "${1-}"; then
                    log_error -l base_bash_libs.std "$helper_name: timeout seconds must be a positive integer."
                    return 1
                fi
                __std_decimal_integer_value__ timeout_seconds "$1"
                shift
                ;;
            --max-attempts | --retry-attempts)
                shift
                if (($# == 0)) || ! __std_is_positive_integer__ "${1-}"; then
                    log_error -l base_bash_libs.std "$helper_name: max attempts must be a positive integer."
                    return 1
                fi
                __std_decimal_integer_value__ max_attempts "$1"
                shift
                ;;
            --retry-delay)
                shift
                if (($# == 0)) || ! __std_is_non_negative_integer__ "${1-}"; then
                    log_error -l base_bash_libs.std "$helper_name: retry delay seconds must be a non-negative integer."
                    return 1
                fi
                __std_decimal_integer_value__ retry_delay "$1"
                shift
                ;;
            --sensitive)
                sensitive=1
                shift
                ;;
            --safe-display)
                safe_display_set=1
                shift
                if (($# == 0)) || [[ "${1-}" == -* ]]; then
                    log_error -l base_bash_libs.std \
                        "$helper_name: --safe-display requires a non-empty printable ASCII label that does not begin with -."
                    return 1
                fi
                safe_display="$1"
                shift
                ;;
            --)
                option_terminator_seen=1
                shift
                break
                ;;
            *)
                if [[ "${1-}" == --* ]]; then
                    log_error -l base_bash_libs.std \
                        "$helper_name: unknown runner option. Use -- before commands that begin with --."
                    return 1
                fi
                break
                ;;
        esac
    done

    if ((safe_display_set && ! sensitive)); then
        log_error -l base_bash_libs.std "$helper_name: --safe-display is valid only with --sensitive."
        return 1
    fi
    if ((safe_display_set)) && ! __std_is_safe_display__ "$safe_display"; then
        log_error -l base_bash_libs.std \
            "$helper_name: --safe-display requires a non-empty printable ASCII label that does not begin with -."
        return 1
    fi
    if ((sensitive && ! option_terminator_seen)); then
        log_error -l base_bash_libs.std \
            "$helper_name: --sensitive requires -- before the command."
        return 1
    fi

    # Check if the command is empty.
    if [[ $# -eq 0 ]]; then
        log_error -l base_bash_libs.std "$helper_name: No command provided."
        return 1
    fi

    local __std_run_immutable_command_display
    __std_render_command_display__ __std_run_immutable_command_display "$sensitive" "$safe_display" \
        '[sensitive command; arguments hidden]' "$@" || {
        log_error -l base_bash_libs.std "$helper_name: could not render a safe command diagnostic."
        return 1
    }
    readonly __std_run_immutable_command_display

    # Bash functions execute in the caller's dynamic scope. Freeze every
    # parsed value that remains authoritative after command execution, and use
    # only these uniquely prefixed copies below. A command may happen to assign
    # generic names such as `timeout_seconds` or `quiet`; those assignments
    # must not alter retry behavior or become framework-generated diagnostics.
    local -r __std_run_policy_exit_on_failure="$exit_on_failure"
    local -r __std_run_policy_quiet="$quiet"
    local -r __std_run_policy_timeout_seconds="$timeout_seconds"
    local -r __std_run_policy_max_attempts="$max_attempts"
    local -r __std_run_policy_retry_delay="$retry_delay"

    # --- Dry-Run Handling ---
    if is_dry_run; then
        local policy_description __std_dry_run_message
        __std_join_run_policy__ policy_description \
            "$__std_run_policy_timeout_seconds" \
            "$__std_run_policy_max_attempts" \
            "$__std_run_policy_retry_delay"

        # Ordinary commands use a copy-pastable %q rendering. Sensitive
        # commands use only the caller-vetted label or the protected marker;
        # the renderer does not inspect or format their command arguments.
        if [[ -n "$policy_description" ]]; then
            __std_dry_run_message="[DRY-RUN] Would run with ${policy_description}: ${__std_run_immutable_command_display}"
        else
            __std_dry_run_message="[DRY-RUN] Would run: ${__std_run_immutable_command_display}"
        fi
        __std_emit_dry_run_plan__ "$__std_dry_run_message"
        return $?
    fi

    # --- Execution ---
    # Execute the command. Using "$@" is the key. It expands each argument
    # as a separate, quoted string, preserving spaces and special characters.
    # This is the safe, modern alternative to using `eval`.
    if [[ -n "$__std_run_policy_timeout_seconds" ]]; then
        __std_timeout_backend_detect__ timeout_path
    fi
    local -r __std_run_policy_timeout_path="$timeout_path"

    local __std_run_attempt_number=1 __std_run_attempts_completed=0
    local __std_run_exit_code=0 __std_run_message __std_run_outcome=command
    while ((__std_run_attempt_number <= __std_run_policy_max_attempts)); do
        if __std_run_once__ \
            __std_run_outcome \
            "$__std_run_policy_timeout_seconds" \
            "$__std_run_policy_timeout_path" \
            "$__std_run_attempt_number" \
            "$@"; then
            return 0
        else
            __std_run_exit_code=$?
        fi
        __std_run_attempts_completed="$__std_run_attempt_number"
        if [[ "$__std_run_outcome" == infrastructure ||
            "$__std_run_outcome" == interrupted ]]; then
            break
        fi

        if ((__std_run_attempt_number < __std_run_policy_max_attempts)); then
            if ((! __std_run_policy_quiet)); then
                __std_run_status_message__ __std_run_message \
                    "$__std_run_exit_code" "$__std_run_policy_timeout_seconds" \
                    "$__std_run_outcome" \
                    "$__std_run_immutable_command_display"
                log_warn -l base_bash_libs.std \
                    "${__std_run_message} (attempt ${__std_run_attempt_number} of ${__std_run_policy_max_attempts}; retrying)."
            fi
            if ((__std_run_policy_retry_delay > 0)); then
                __std_sleep_interval__ "$__std_run_policy_retry_delay"
            fi
        fi

        __std_run_attempt_number=$((__std_run_attempt_number + 1))
    done

    if ((__std_run_exit_code)); then
        if ((__std_run_attempts_completed > 1)); then
            if [[ "$__std_run_outcome" == timeout ]]; then
                __std_run_message="Command timed out after ${__std_run_policy_timeout_seconds}s on final attempt (${__std_run_attempts_completed} attempts): ${__std_run_immutable_command_display}"
            else
                __std_run_message="Command failed after ${__std_run_attempts_completed} attempts (exit ${__std_run_exit_code}): ${__std_run_immutable_command_display}"
            fi
        else
            __std_run_status_message__ __std_run_message \
                "$__std_run_exit_code" "$__std_run_policy_timeout_seconds" \
                "$__std_run_outcome" \
                "$__std_run_immutable_command_display"
        fi
        if ((__std_run_policy_exit_on_failure)); then
            exit_if_error "$__std_run_exit_code" "$__std_run_message"
        else
            if ((! __std_run_policy_quiet)); then
                log_warn -l base_bash_libs.std "$__std_run_message (continuing)."
            fi
            return "$__std_run_exit_code"
        fi
    fi

    return 0
}

std_run() {
    __std_run_impl__ std_run "$@"
}

__std_sleep_interval__() {
    if [[ -x /bin/sleep ]]; then
        /bin/sleep "$1"
    else
        sleep "$1"
    fi
}


__std_timeout_candidate_is_gnu__() {
    (($# == 1)) || return 1
    local __std_timeout_candidate_path="$1"
    local __std_timeout_candidate_version __std_timeout_candidate_first_line

    [[ -x "$__std_timeout_candidate_path" ]] || return 1
    __std_timeout_candidate_version="$(
        "$__std_timeout_candidate_path" --version 2>/dev/null
    )" || return 1
    __std_timeout_candidate_first_line="${__std_timeout_candidate_version%%$'\n'*}"
    [[ "$__std_timeout_candidate_first_line" == "timeout (GNU coreutils)" ||
        "$__std_timeout_candidate_first_line" == "timeout (GNU coreutils) "* ]]
}

__std_timeout_backend_detect__() {
    (($# == 1)) || return 1
    local __std_timeout_backend_result_name="$1"
    local timeout_backend_candidate="" __std_timeout_backend_name

    printf -v "$__std_timeout_backend_result_name" '%s' ""
    for __std_timeout_backend_name in timeout gtimeout; do
        timeout_backend_candidate=""
        if std_command_path timeout_backend_candidate \
            "$__std_timeout_backend_name" &&
            __std_timeout_candidate_is_gnu__ \
                "$timeout_backend_candidate"; then
            printf -v "$__std_timeout_backend_result_name" '%s' \
                "$timeout_backend_candidate"
            return 0
        fi
    done
    return 0
}

# GNU timeout and gtimeout are deadline clocks only. They never receive the
# caller's argv: the framework owns the process group and performs TERM/KILL.
__std_timeout_wait_clock__() {
    local __std_timeout_clock_path="$1" __std_timeout_clock_seconds="$2"
    local __std_timeout_clock_fd="$3" __std_timeout_clock_status=125
    local __std_timeout_clock_dd="" __std_timeout_clock_byte=""

    if [[ -n "$__std_timeout_clock_path" ]]; then
        if [[ -x /bin/dd ]]; then
            __std_timeout_clock_dd=/bin/dd
        else
            __std_timeout_clock_dd="$(type -P dd 2>/dev/null || true)"
        fi
        [[ -n "$__std_timeout_clock_dd" && -x "$__std_timeout_clock_dd" ]] ||
            return 125
        if "$__std_timeout_clock_path" --foreground --signal=KILL \
            "${__std_timeout_clock_seconds}s" "$__std_timeout_clock_dd" \
            bs=1 count=1 <&"$__std_timeout_clock_fd" >/dev/null 2>&1; then
            __std_timeout_clock_status=0
        else
            __std_timeout_clock_status=$?
        fi
        case "$__std_timeout_clock_status" in
            0) return 0 ;;
            124 | 137) return 124 ;;
            *) return 125 ;;
        esac
    fi

    if IFS= read -r -n 1 -t "$__std_timeout_clock_seconds" \
        -u "$__std_timeout_clock_fd" __std_timeout_clock_byte; then
        return 0
    fi
    return 124
}

__std_timeout_latch_cancel__() {
    local __std_timeout_latched_signal="$1" __std_timeout_latched_status="$2"

    if ((__std_timeout_cancel_status == 0)); then
        __std_timeout_cancel_signal="$__std_timeout_latched_signal"
        __std_timeout_cancel_status="$__std_timeout_latched_status"
        if [[ -n "$__std_timeout_command_pid" ]]; then
            builtin kill "-$__std_timeout_latched_signal" -- \
                "-$__std_timeout_command_pid" 2>/dev/null || true
        fi
    elif [[ -n "$__std_timeout_command_pid" ]]; then
        builtin kill -KILL -- "-$__std_timeout_command_pid" 2>/dev/null || true
    fi
}

__std_timeout_command_wrapper__() {
    local __std_timeout_wrapper_status=0
    local __std_timeout_wrapper_cancel_status=0
    local __std_timeout_wrapper_child_pid=""
    local __std_timeout_wrapper_release_byte=""
    local __std_timeout_wrapper_status_record=""

    # The wrapper job starts with stderr redirected away so Bash cannot print
    # a job-control `Killed: 9` notification when its process group is
    # escalated. Restore the caller's original stderr before launching argv;
    # the command therefore retains byte-for-byte diagnostics.
    if [[ -n "${__std_timeout_stderr_fd-}" ]]; then
        exec 2>&"$__std_timeout_stderr_fd"
        exec {__std_timeout_stderr_fd}>&-
    fi

    trap - EXIT
    if ((__std_timeout_hup_ignored)); then
        trap '' HUP
    else
        trap '__std_timeout_wrapper_cancel_status=129' HUP
    fi
    if ((__std_timeout_int_ignored)); then
        trap '' INT
    else
        trap '__std_timeout_wrapper_cancel_status=130' INT
    fi
    if ((__std_timeout_quit_ignored)); then
        trap '' QUIT
    else
        trap '__std_timeout_wrapper_cancel_status=131' QUIT
    fi
    if ((__std_timeout_term_ignored)); then
        trap '' TERM
    else
        trap '__std_timeout_wrapper_cancel_status=143' TERM
    fi
    if [[ -n "${__std_timeout_timer_fd-}" ]]; then
        exec {__std_timeout_timer_fd}>&-
    fi

    set +m
    if ((__std_timeout_has_stdin)); then
        "${__std_timeout_command_argv[@]}" <&0 &
    else
        "${__std_timeout_command_argv[@]}" <&- &
    fi
    __std_timeout_wrapper_child_pid=$!
    while :; do
        if wait "$__std_timeout_wrapper_child_pid" 2>/dev/null; then
            __std_timeout_wrapper_status=0
            break
        else
            __std_timeout_wrapper_status=$?
        fi
        builtin kill -0 "$__std_timeout_wrapper_child_pid" 2>/dev/null ||
            break
    done
    ((__std_timeout_wrapper_cancel_status != 0)) &&
        __std_timeout_wrapper_status="$__std_timeout_wrapper_cancel_status"

    # Keep the process-group leader alive through the final KILL so its PGID
    # cannot be recycled into an unrelated process group.
    __std_timeout_wrapper_status_record="S$(printf '%03d' \
        "$__std_timeout_wrapper_status")"
    if ! builtin printf '%s' "$__std_timeout_wrapper_status_record" \
        >|"$__std_timeout_status_file" 2>/dev/null; then
        return 1
    fi
    IFS= read -r -n 1 -u "$__std_timeout_status_fd" \
        __std_timeout_wrapper_release_byte 2>/dev/null || true
    return "$__std_timeout_wrapper_status"
}

__std_timeout_watchdog__() {
    local __std_timeout_watchdog_seconds="$1"
    local __std_timeout_watchdog_path="$2"
    local __std_timeout_watchdog_fd="$3"
    local __std_timeout_watchdog_command_pid="$4"
    local __std_timeout_watchdog_status_file="$5"
    local __std_timeout_watchdog_clock_status=125
    local __std_timeout_watchdog_final_status=125

    if __std_timeout_wait_clock__ "$__std_timeout_watchdog_path" \
        "$__std_timeout_watchdog_seconds" "$__std_timeout_watchdog_fd"; then
        __std_timeout_watchdog_final_status=0
        builtin printf 'T%03d' "$__std_timeout_watchdog_final_status" \
            >|"$__std_timeout_watchdog_status_file" 2>/dev/null || true
    else
        __std_timeout_watchdog_clock_status=$?
        case "$__std_timeout_watchdog_clock_status" in
            124) __std_timeout_watchdog_final_status=124 ;;
            *)   __std_timeout_watchdog_final_status=125 ;;
        esac
        # Publish the timer result before escalation. The supervisor must not
        # mistake the wrapper's signal-derived status (143/137) for the
        # deadline or clock outcome that caused the escalation.
        builtin printf 'T%03d' "$__std_timeout_watchdog_final_status" \
            >|"$__std_timeout_watchdog_status_file" 2>/dev/null || true

        builtin kill -TERM -- "-$__std_timeout_watchdog_command_pid" \
            2>/dev/null || true
        __std_sleep_interval__ 1 || true
        builtin kill -KILL -- "-$__std_timeout_watchdog_command_pid" \
            2>/dev/null || true
    fi
    return "$__std_timeout_watchdog_final_status"
}

__std_timeout_emit_error__() {
    local __std_timeout_error_message="$1"
    builtin printf 'base-bash-libs: TIMEOUT ERROR: %s\n' \
        "$__std_timeout_error_message" >&2 || true
}

__std_timeout_mkfifo_path__() {
    (($# == 1)) || return 1
    local __std_timeout_mkfifo_result_name="$1"
    local __std_timeout_mkfifo_candidate=""
    for __std_timeout_mkfifo_candidate in /usr/bin/mkfifo /bin/mkfifo; do
        if [[ -x "$__std_timeout_mkfifo_candidate" ]]; then
            printf -v "$__std_timeout_mkfifo_result_name" '%s' \
                "$__std_timeout_mkfifo_candidate"
            return 0
        fi
    done
    printf -v "$__std_timeout_mkfifo_result_name" '%s' ""
    return 1
}

__std_timeout_chmod_path__() {
    (($# == 1)) || return 1
    local __std_timeout_chmod_result_name="$1"
    local __std_timeout_chmod_candidate=""
    for __std_timeout_chmod_candidate in /usr/bin/chmod /bin/chmod; do
        if [[ -x "$__std_timeout_chmod_candidate" ]]; then
            printf -v "$__std_timeout_chmod_result_name" '%s' \
                "$__std_timeout_chmod_candidate"
            return 0
        fi
    done
    printf -v "$__std_timeout_chmod_result_name" '%s' ""
    return 1
}

__std_run_with_timeout_supervisor__() {
    local __std_timeout_outcome_result_name="$1"
    local __std_timeout_seconds="$2" __std_timeout_path="$3"
    shift 3
    local __std_timeout_final_status=125 __std_timeout_outcome=infrastructure
    local __std_timeout_fifo="" __std_timeout_status_fifo=""
    local __std_timeout_status_file=""
    local __std_timeout_timer_status_file=""
    local __std_timeout_mkfifo_path="" __std_timeout_chmod_path=""
    local __std_timeout_timer_fd="" __std_timeout_status_fd=""
    local __std_timeout_stderr_fd=""
    local __std_timeout_has_stdin=0
    local __std_timeout_command_pid="" __std_timeout_timer_pid=""
    local __std_timeout_timer_status=125 __std_timeout_run_status=125
    local __std_timeout_child_status="" __std_timeout_status_record=""
    local __std_timeout_timer_early_status="" __std_timeout_timer_status_record=""
    local __std_timeout_release_byte=""
    local __std_timeout_cancel_status=0 __std_timeout_cancel_signal=""
    local __std_timeout_saved_hup_trap __std_timeout_saved_int_trap
    local __std_timeout_saved_quit_trap __std_timeout_saved_term_trap
    local __std_timeout_hup_ignored=0 __std_timeout_int_ignored=0
    local __std_timeout_quit_ignored=0 __std_timeout_term_ignored=0
    local __std_timeout_monitor_was_enabled=0
    local __std_timeout_setup_failed=0
    local -a __std_timeout_command_argv=("$@")

    if (($# == 0)); then
        __std_timeout_emit_error__ "no command was provided."
        printf -v "$__std_timeout_outcome_result_name" '%s' infrastructure
        return 125
    fi
    if [[ -t 0 ]]; then
        __std_timeout_emit_error__ \
            "timed commands require non-terminal stdin; redirect stdin from a pipe or /dev/null."
        printf -v "$__std_timeout_outcome_result_name" '%s' infrastructure
        return 125
    fi

    if ! __std_make_internal_temp_file__ --keep \
        __std_timeout_fifo base-bash-libs-timeout-clock; then
        printf -v "$__std_timeout_outcome_result_name" '%s' infrastructure
        __std_timeout_emit_error__ "could not allocate the private timeout clock channel."
        return 125
    fi
    __std_make_internal_temp_file__ --keep \
        __std_timeout_status_fifo base-bash-libs-timeout-status || {
        rm -f -- "$__std_timeout_fifo"
        printf -v "$__std_timeout_outcome_result_name" '%s' infrastructure
        __std_timeout_emit_error__ "could not allocate the private timeout status channel."
        return 125
    }
    if ! __std_make_internal_temp_file__ --keep \
        __std_timeout_status_file base-bash-libs-timeout-status-record; then
        rm -f -- "$__std_timeout_fifo" "$__std_timeout_status_fifo"
        printf -v "$__std_timeout_outcome_result_name" '%s' infrastructure
        __std_timeout_emit_error__ "could not allocate the private timeout status record."
        return 125
    fi
    if ! __std_make_internal_temp_file__ --keep \
        __std_timeout_timer_status_file base-bash-libs-timeout-timer-record; then
        rm -f -- "$__std_timeout_fifo" "$__std_timeout_status_fifo" \
            "$__std_timeout_status_file"
        printf -v "$__std_timeout_outcome_result_name" '%s' infrastructure
        __std_timeout_emit_error__ "could not allocate the private timeout timer record."
        return 125
    fi
    if ! __std_timeout_mkfifo_path__ __std_timeout_mkfifo_path ||
        ! __std_timeout_chmod_path__ __std_timeout_chmod_path ||
        ! rm -f -- "$__std_timeout_fifo" "$__std_timeout_status_fifo" 2>/dev/null ||
        ! "$__std_timeout_mkfifo_path" "$__std_timeout_fifo" \
            "$__std_timeout_status_fifo" \
            2>/dev/null ||
        ! "$__std_timeout_chmod_path" 600 "$__std_timeout_fifo" \
            "$__std_timeout_status_fifo" "$__std_timeout_status_file" \
            "$__std_timeout_timer_status_file" \
            2>/dev/null ||
        ! exec {__std_timeout_timer_fd}<>"$__std_timeout_fifo" ||
        ! exec {__std_timeout_status_fd}<>"$__std_timeout_status_fifo"; then
        rm -f -- "$__std_timeout_fifo" "$__std_timeout_status_fifo" \
            "$__std_timeout_status_file" "$__std_timeout_timer_status_file"
        __std_timeout_emit_error__ "could not create the private timeout control channels."
        printf -v "$__std_timeout_outcome_result_name" '%s' infrastructure
        return 125
    fi

    if [[ -e /dev/fd/0 ]]; then
        __std_timeout_has_stdin=1
    fi
    if ((__std_timeout_setup_failed)); then
        exec {__std_timeout_timer_fd}>&-
        exec {__std_timeout_status_fd}>&-
        rm -f -- "$__std_timeout_fifo" "$__std_timeout_status_fifo" \
            "$__std_timeout_status_file" "$__std_timeout_timer_status_file"
        __std_timeout_emit_error__ "could not preserve command stdin."
        printf -v "$__std_timeout_outcome_result_name" '%s' infrastructure
        return 125
    fi

    [[ $- == *m* ]] && __std_timeout_monitor_was_enabled=1
    __std_timeout_saved_hup_trap="$(trap -p HUP || true)"
    __std_timeout_saved_int_trap="$(trap -p INT || true)"
    __std_timeout_saved_quit_trap="$(trap -p QUIT || true)"
    __std_timeout_saved_term_trap="$(trap -p TERM || true)"
    [[ "$__std_timeout_saved_hup_trap" == *"'' SIGHUP" ||
        "$__std_timeout_saved_hup_trap" == *"'' HUP" ]] &&
        __std_timeout_hup_ignored=1
    [[ "$__std_timeout_saved_int_trap" == *"'' SIGINT" ||
        "$__std_timeout_saved_int_trap" == *"'' INT" ]] &&
        __std_timeout_int_ignored=1
    [[ "$__std_timeout_saved_quit_trap" == *"'' SIGQUIT" ||
        "$__std_timeout_saved_quit_trap" == *"'' QUIT" ]] &&
        __std_timeout_quit_ignored=1
    [[ "$__std_timeout_saved_term_trap" == *"'' SIGTERM" ||
        "$__std_timeout_saved_term_trap" == *"'' TERM" ]] &&
        __std_timeout_term_ignored=1

    if ((__std_timeout_hup_ignored)); then trap '' HUP; else trap '__std_timeout_latch_cancel__ HUP 129' HUP; fi
    if ((__std_timeout_int_ignored)); then trap '' INT; else trap '__std_timeout_latch_cancel__ INT 130' INT; fi
    if ((__std_timeout_quit_ignored)); then trap '' QUIT; else trap '__std_timeout_latch_cancel__ QUIT 131' QUIT; fi
    if ((__std_timeout_term_ignored)); then trap '' TERM; else trap '__std_timeout_latch_cancel__ TERM 143' TERM; fi

    if ! set -m; then
        __std_timeout_setup_failed=1
    else
        if ! exec {__std_timeout_stderr_fd}>&2; then
            __std_timeout_setup_failed=1
        else
            if ((__std_timeout_has_stdin)); then
                __std_timeout_command_wrapper__ <&0 2>/dev/null &
            else
                __std_timeout_command_wrapper__ <&- 2>/dev/null &
            fi
            __std_timeout_command_pid=$!
            __std_timeout_watchdog__ "$__std_timeout_seconds" \
                "$__std_timeout_path" "$__std_timeout_timer_fd" \
                "$__std_timeout_command_pid" \
                "$__std_timeout_timer_status_file" 2>/dev/null &
            __std_timeout_timer_pid=$!
            # Remove the process-group sentinel from Bash's job table before
            # escalation. Its terminal status is carried by the private
            # record, so no job-table wait is needed and Bash cannot leak a
            # `Killed: 9` notification when the group is deliberately killed.
            builtin disown "$__std_timeout_command_pid" 2>/dev/null || true
            # Both asynchronous jobs already have their isolated process
            # groups. Disable monitor notifications while they are reaped.
            set +m
        fi
    fi

    if ((__std_timeout_setup_failed)); then
        __std_timeout_emit_error__ "could not enable isolated process-group supervision."
        if [[ -n "$__std_timeout_command_pid" ]]; then
            builtin kill -KILL -- "-$__std_timeout_command_pid" \
                2>/dev/null || true
            wait "$__std_timeout_command_pid" 2>/dev/null || true
        fi
        if [[ -n "$__std_timeout_timer_pid" ]]; then
            builtin kill -KILL -- "-$__std_timeout_timer_pid" \
                2>/dev/null || true
            wait "$__std_timeout_timer_pid" 2>/dev/null || true
        fi
    else
        while [[ -z "$__std_timeout_child_status" &&
            -z "$__std_timeout_timer_early_status" &&
            "$__std_timeout_cancel_status" == 0 ]]; do
            if [[ -s "$__std_timeout_timer_status_file" ]]; then
                __std_timeout_timer_status_record="$(<"$__std_timeout_timer_status_file")"
                case "$__std_timeout_timer_status_record" in
                    T[0-9][0-9][0-9])
                        __std_timeout_timer_early_status="$((10#${__std_timeout_timer_status_record:1}))"
                        break
                        ;;
                esac
            fi
            if [[ -s "$__std_timeout_status_file" ]]; then
                __std_timeout_status_record="$(<"$__std_timeout_status_file")"
                if [[ "$__std_timeout_status_record" =~ ^S[0-9]{3}$ ]]; then
                    __std_timeout_child_status="$((10#${__std_timeout_status_record:1}))"
                    break
                fi
            fi
            builtin kill -0 "$__std_timeout_command_pid" 2>/dev/null ||
                break
            __std_sleep_interval__ 0.01 || true
        done

        if ((__std_timeout_cancel_status != 0)); then
            { builtin printf 'x' >&"$__std_timeout_timer_fd"; } 2>/dev/null || true
            if wait "$__std_timeout_timer_pid" 2>/dev/null; then
                __std_timeout_timer_status=0
            else
                __std_timeout_timer_status=$?
            fi
            if [[ -z "$__std_timeout_child_status" &&
                -s "$__std_timeout_status_file" ]]; then
                __std_timeout_status_record="$(<"$__std_timeout_status_file")"
                case "$__std_timeout_status_record" in
                    S[0-9][0-9][0-9])
                        __std_timeout_child_status="$((10#${__std_timeout_status_record:1}))"
                        ;;
                esac
            fi
            if [[ -z "$__std_timeout_child_status" &&
                -n "$__std_timeout_timer_early_status" ]]; then
                __std_timeout_timer_status="$__std_timeout_timer_early_status"
            fi
            __std_sleep_interval__ 1 || true
            builtin kill -KILL -- "-$__std_timeout_command_pid" \
                2>/dev/null || true
            wait "$__std_timeout_command_pid" 2>/dev/null || true
            __std_timeout_final_status="$__std_timeout_cancel_status"
            __std_timeout_outcome=interrupted
        else
            { builtin printf 'x' >&"$__std_timeout_timer_fd"; } 2>/dev/null || true
            if wait "$__std_timeout_timer_pid" 2>/dev/null; then
                __std_timeout_timer_status=0
            else
                __std_timeout_timer_status=$?
            fi
            if [[ -z "$__std_timeout_child_status" &&
                -s "$__std_timeout_status_file" ]]; then
                __std_timeout_status_record="$(<"$__std_timeout_status_file")"
                case "$__std_timeout_status_record" in
                    S[0-9][0-9][0-9])
                        __std_timeout_child_status="$((10#${__std_timeout_status_record:1}))"
                        ;;
                esac
            fi
            if [[ -z "$__std_timeout_child_status" &&
                -n "$__std_timeout_timer_early_status" ]]; then
                __std_timeout_timer_status="$__std_timeout_timer_early_status"
            fi
            if [[ -n "$__std_timeout_cancel_signal" ]]; then
                __std_timeout_final_status="$__std_timeout_cancel_status"
                __std_timeout_outcome=interrupted
            elif [[ -n "$__std_timeout_child_status" ]]; then
                # The private status record is written only by the wrapper as
                # S%03d from Bash's wait status, so a non-empty record is
                # already constrained to the command's 0..255 exit range.
                __std_timeout_run_status="$__std_timeout_child_status"
                case "$__std_timeout_timer_status" in
                    0)
                        __std_timeout_final_status="$__std_timeout_run_status"
                        __std_timeout_outcome="command"
                        ;;
                    124)
                        __std_timeout_final_status=124
                        __std_timeout_outcome=timeout
                        ;;
                    125)
                        # A command that has already published a terminal
                        # status completed before the deadline clock was
                        # canceled.  Preserve that command result even when
                        # an older Bash/coreutils combination reports the
                        # canceled clock as an infrastructure failure.
                        if ((__std_timeout_run_status == 137 ||
                            __std_timeout_run_status == 143)); then
                            # These are the wrapper statuses produced when an
                            # external clock fails and escalates the group.
                            # Do not expose the wrapper's signal status as a
                            # natural command result.
                            __std_timeout_final_status=125
                            __std_timeout_outcome=infrastructure
                        else
                            __std_timeout_final_status="$__std_timeout_run_status"
                            __std_timeout_outcome="command"
                        fi
                        ;;
                    *)
                        __std_timeout_final_status=125
                        __std_timeout_outcome=infrastructure
                        ;;
                esac
            else
                case "$__std_timeout_timer_status" in
                    124)
                        __std_timeout_final_status=124
                        __std_timeout_outcome=timeout
                        ;;
                    *)
                        __std_timeout_final_status=125
                        __std_timeout_outcome=infrastructure
                        ;;
                esac
            fi
        fi
        { builtin printf 'x' >&"$__std_timeout_status_fd"; } 2>/dev/null || true
        wait "$__std_timeout_command_pid" 2>/dev/null || true
    fi

    exec {__std_timeout_timer_fd}>&-
    exec {__std_timeout_status_fd}>&-
    if [[ -n "$__std_timeout_stderr_fd" ]]; then
        exec {__std_timeout_stderr_fd}>&-
    fi
    rm -f -- "$__std_timeout_fifo" "$__std_timeout_status_fifo" \
        "$__std_timeout_status_file" "$__std_timeout_timer_status_file"

    if ((__std_timeout_monitor_was_enabled)); then
        set -m
    else
        set +m
    fi
    # Restore each saved disposition directly. Resetting all four signals to
    # their defaults first creates a small window in which a caller's ignored
    # TERM (or a signal queued during cleanup) can kill the supervising shell.
    # An empty saved trap is the only case that needs the default disposition.
    if [[ -n "$__std_timeout_saved_hup_trap" ]]; then
        eval "$__std_timeout_saved_hup_trap"
    else
        trap - HUP
    fi
    if [[ -n "$__std_timeout_saved_int_trap" ]]; then
        eval "$__std_timeout_saved_int_trap"
    else
        trap - INT
    fi
    if [[ -n "$__std_timeout_saved_quit_trap" ]]; then
        eval "$__std_timeout_saved_quit_trap"
    else
        trap - QUIT
    fi
    if [[ -n "$__std_timeout_saved_term_trap" ]]; then
        eval "$__std_timeout_saved_term_trap"
    else
        trap - TERM
    fi

    printf -v "$__std_timeout_outcome_result_name" '%s' \
        "$__std_timeout_outcome"
    if [[ -n "$__std_timeout_cancel_signal" ]]; then
        builtin kill "-$__std_timeout_cancel_signal" "$BASHPID" \
            2>/dev/null || true
    fi
    return "$__std_timeout_final_status"
}

__std_run_with_timeout_fallback__() {
    local __std_timeout_fallback_seconds="$1"
    shift
    local __std_timeout_fallback_outcome=command
    __std_run_with_timeout_supervisor__ __std_timeout_fallback_outcome \
        "$__std_timeout_fallback_seconds" "" "$@"
}
############################################## FILE AND DIRECTORY HANDLING ############################################

#
# safe_mkdir: Attempt to create directories and exit on failure.
#             Creates as many directories as possible.
#
# Usage: safe_mkdir [-p] dir1 dir2 ...
#
safe_mkdir() {
    local dir opt failed_dirs=() mkdir_args=()
    local OPTIND=1

    while getopts ":p" opt; do
        case "$opt" in
            p) mkdir_args=(-p) ;;
            \?)
                log_error -l base_bash_libs.std "safe_mkdir: invalid option '-$OPTARG'"
                return 1
                ;;
        esac
    done
    shift $((OPTIND - 1))

    if (($# == 0)); then
        log_warn -l base_bash_libs.std "safe_mkdir: No directories provided to create."
        return 0
    fi

    for dir; do
        [[ -d "$dir" ]] && continue
        if ! mkdir "${mkdir_args[@]+"${mkdir_args[@]}"}" -- "$dir"; then
            failed_dirs+=("$dir")
        fi
    done
    [[ -z "${failed_dirs[0]+set}" ]] || exit_if_error 1 "Failed to create directories: ${failed_dirs[*]}"
    return 0
}

#
# safe_touch - Creates or updates the timestamp of one or more files.
#
# This function iterates through all provided file paths. It attempts to
# 'touch' each file. If any operation fails (e.g., due to permissions),
# it collects the names of the failed files and reports them all in a
# single fatal error at the end.
#
# Usage:
#   safe_touch "/tmp/file1.log" "/var/run/app.pid"
#
# Arguments:
#   $@: One or more file paths to touch.
#
safe_touch() {
    local failed_files=()
    local file touch_path

    if (($# == 0)); then
        log_warn -l base_bash_libs.std "safe_touch: No files provided to touch."
        return 0
    fi

    for file; do
        touch_path="$file"
        [[ "$touch_path" == -* ]] && touch_path="./$touch_path"
        if ! touch "$touch_path" 2>/dev/null; then
            failed_files+=("$file")
        fi
    done

    if [[ -n "${failed_files[0]+set}" ]]; then
        fatal_error "Failed to touch the following files: ${failed_files[*]}"
    fi

    return 0
}

#
# safe_truncate - Truncates one or more files to zero bytes.
#
# This function iterates through all provided file paths. It attempts to
# truncate each file. If any operation fails (e.g., due to permissions),
# it collects the names of the failed files and reports them all in a
# single fatal error at the end.
#
# Usage:
#   safe_truncate "/var/log/app.log" "/tmp/data.tmp"
#
# Arguments:
#   $@: One or more file paths to truncate.
#
safe_truncate() {
    local failed_files=()
    local file

    if (($# == 0)); then
        log_warn -l base_bash_libs.std "safe_truncate: No files provided to truncate."
        return 0
    fi

    for file; do
        # The > redirection is the simplest way to truncate a file.
        # We redirect stderr to /dev/null to suppress system error messages,
        # as we will provide our own comprehensive error message.
        if ! : > "$file" 2>/dev/null; then
            failed_files+=("$file")
        fi
    done

    if [[ -n "${failed_files[0]+set}" ]]; then
        fatal_error "Failed to truncate the following files: ${failed_files[*]}"
    fi

    return 0
}

######################################################## CLEANUP #######################################################

__std_return_status__() {
    return "$1"
}

__std_get_trap_command__() {
    local result_name="${1-}" signal="${2-}" trap_name trap_spec=""
    local trap_prefix="trap -- '" trap_suffix

    case "$signal" in
        EXIT | DEBUG)
            trap_name="$signal"
            ;;
        INT | TERM)
            trap_name="SIG$signal"
            ;;
        *)
            printf -v "$result_name" '%s' ""
            return 1
            ;;
    esac

    trap_suffix="' $trap_name"
    trap_spec="$(trap -p "$signal" || true)"
    if [[ "$trap_spec" == "$trap_prefix"*"$trap_suffix" ]]; then
        trap_spec="${trap_spec#"$trap_prefix"}"
        trap_spec="${trap_spec%"$trap_suffix"}"
        printf -v "$result_name" '%s' "$trap_spec"
    else
        printf -v "$result_name" '%s' ""
    fi
}

__std_get_exit_trap_command__() {
    __std_get_trap_command__ "$1" EXIT
}

__std_restore_trap_spec__() {
    local signal="$1" trap_spec="$2"

    if [[ -n "$trap_spec" ]]; then
        eval "$trap_spec"
    else
        trap - "$signal"
    fi
}

__std_run_saved_trap_command__() {
    local trap_command="$1" exit_status="$2"

    [[ -n "$trap_command" ]] || return 0
    (
        __std_return_status__ "$exit_status"
        eval "$trap_command"
    ) || true
}

__std_stat_path_identity__() {
    local result_name="$1" path="$2" stat_identity

    if stat_identity="$(stat -c '%d:%i' -- "$path" 2>/dev/null)"; then
        printf -v "$result_name" '%s' "$stat_identity"
        return 0
    fi
    if stat_identity="$(stat -f '%d:%i' -- "$path" 2>/dev/null)"; then
        printf -v "$result_name" '%s' "$stat_identity"
        return 0
    fi
    return 1
}

__std_capture_cleanup_path_fingerprint__() {
    local result_name="$1" path="$2" current="$2" component_identity path_fingerprint=""

    [[ -e "$path" || -L "$path" ]] || return 1
    while :; do
        __std_stat_path_identity__ component_identity "$current" || return 1
        path_fingerprint+="$current"$'\t'"$component_identity"$'\n'
        [[ "$current" == "/" ]] && break
        current="$(dirname -- "$current")" || return 1
    done

    printf -v "$result_name" '%s' "$path_fingerprint"
}

__std_cleanup_path_fingerprint_matches__() {
    local path="$1" fingerprint="${__std_cleanup_path_fingerprints[$1]-}"
    local expected_path expected_identity actual_identity

    [[ -n "$fingerprint" && "$fingerprint" != UNSAFE ]] || return 1
    while IFS=$'\t' read -r expected_path expected_identity; do
        [[ -n "$expected_path" ]] || continue
        __std_stat_path_identity__ actual_identity "$expected_path" || return 1
        [[ "$actual_identity" == "$expected_identity" ]] || return 1
    done <<< "$fingerprint"
}

__std_cleanup_delete_path__() {
    local cleanup_path="$1"
    local fingerprint="${__std_cleanup_path_fingerprints[$cleanup_path]-}"

    [[ -e "$cleanup_path" || -L "$cleanup_path" ]] || return 0
    if [[ "$fingerprint" != UNSAFE ]] &&
        ! __std_cleanup_path_fingerprint_matches__ "$cleanup_path"; then
        log_warn -l base_bash_libs.std "Cleanup path '$cleanup_path' changed identity; refusing to remove it."
        return 1
    fi
    if [[ "$fingerprint" == UNSAFE ]]; then
        log_warn -l base_bash_libs.std "Removing explicitly unsafe cleanup path '$cleanup_path'."
    fi
    if ! rm -rf -- "$cleanup_path"; then
        log_warn -l base_bash_libs.std "Cleanup path '$cleanup_path' could not be removed."
        return 1
    fi
    return 0
}

__std_cleanup_refresh_signal_traps__() {
    local current_int_trap current_term_trap

    current_int_trap="$(trap -p INT || true)"
    if [[ "$current_int_trap" != "$__std_cleanup_int_trap_spec" ]]; then
        __std_original_int_trap_spec="$current_int_trap"
        __std_get_trap_command__ __std_original_int_trap INT || true
        if [[ -n "$current_int_trap" && -z "$__std_original_int_trap" ]]; then
            __std_cleanup_int_trap_spec="$current_int_trap"
        else
            trap '__std_cleanup_signal_exit__ INT 130' INT
            __std_cleanup_int_trap_spec="$(trap -p INT || true)"
        fi
    fi

    current_term_trap="$(trap -p TERM || true)"
    if [[ "$current_term_trap" != "$__std_cleanup_term_trap_spec" ]]; then
        __std_original_term_trap_spec="$current_term_trap"
        __std_get_trap_command__ __std_original_term_trap TERM || true
        if [[ -n "$current_term_trap" && -z "$__std_original_term_trap" ]]; then
            __std_cleanup_term_trap_spec="$current_term_trap"
        else
            trap '__std_cleanup_signal_exit__ TERM 143' TERM
            __std_cleanup_term_trap_spec="$(trap -p TERM || true)"
        fi
    fi
}

__std_cleanup_refresh_traps__() {
    local current_exit_trap

    ((__std_cleanup_dispatcher_installed)) || return 0
    current_exit_trap="$(trap -p EXIT || true)"
    if [[ "$current_exit_trap" != "$__std_cleanup_dispatcher_trap_spec" ]]; then
        __std_original_exit_trap_spec="$current_exit_trap"
        __std_get_exit_trap_command__ __std_original_exit_trap || true
        trap '__std_run_cleanup_hooks__' EXIT
        __std_cleanup_dispatcher_trap_spec="$(trap -p EXIT || true)"
    fi
    __std_cleanup_refresh_signal_traps__
}

__std_cleanup_debug_guard__() {
    local current_debug_status=$?

    ((current_debug_status)) && :
    ((__std_cleanup_dispatcher_installed)) || return 0
    (( __std_cleanup_debug_guard_running )) && return 0
    __std_cleanup_debug_guard_running=1

    if [[ -n "$__std_original_debug_trap" ]]; then
        (eval "$__std_original_debug_trap") || true
    fi
    __std_cleanup_refresh_traps__
    __std_cleanup_debug_guard_running=0
    return 0
}

__std_cleanup_signal_exit__() {
    local signal="$1" exit_status="$2"

    case "$signal" in
        INT)
            __std_run_saved_trap_command__ "$__std_original_int_trap" "$exit_status"
            ;;
        TERM)
            __std_run_saved_trap_command__ "$__std_original_term_trap" "$exit_status"
            ;;
    esac

    if (( __std_cleanup_dispatcher_running )); then
        __std_cleanup_pending_signal_status="$exit_status"
        return 0
    fi
    exit "$exit_status"
}

__std_run_cleanup_hooks__() {
    local exit_status=$? entry entry_type entry_value index

    (( __std_cleanup_dispatcher_finished )) && return "$exit_status"
    (( __std_cleanup_dispatcher_running )) && return "$exit_status"
    __std_cleanup_dispatcher_running=1
    trap - DEBUG

    if [[ -n "${__std_original_exit_trap:-}" ]]; then
        __std_run_saved_trap_command__ "$__std_original_exit_trap" "$exit_status"
    fi

    for ((index=${#__std_cleanup_entries[@]} - 1; index >= 0; index--)); do
        entry="${__std_cleanup_entries[index]}"
        entry_type="${entry%%:*}"
        entry_value="${entry#*:}"
        case "$entry_type" in
            hook)
                if ! "$entry_value"; then
                    log_warn -l base_bash_libs.std "Cleanup hook '$entry_value' failed."
                fi
                ;;
            path)
                __std_cleanup_delete_path__ "$entry_value" || true
                ;;
        esac
    done

    if (( __std_cleanup_pending_signal_status )); then
        exit_status="$__std_cleanup_pending_signal_status"
    fi
    __std_cleanup_dispatcher_finished=1
    __std_cleanup_dispatcher_running=0
    if (( __std_cleanup_pending_signal_status )); then
        exit "$exit_status"
    fi
    return "$exit_status" 2>/dev/null || exit "$exit_status"
}

__std_install_cleanup_dispatcher__() {
    if ((__std_cleanup_dispatcher_installed)); then
        return 0
    fi

    __std_cleanup_dispatcher_running=0
    __std_cleanup_dispatcher_finished=0
    __std_cleanup_pending_signal_status=0
    __std_original_exit_trap_spec="$(trap -p EXIT || true)"
    __std_get_exit_trap_command__ __std_original_exit_trap
    __std_original_int_trap_spec="$(trap -p INT || true)"
    __std_get_trap_command__ __std_original_int_trap INT || true
    __std_original_term_trap_spec="$(trap -p TERM || true)"
    __std_get_trap_command__ __std_original_term_trap TERM || true
    __std_original_debug_trap_spec="$(trap -p DEBUG || true)"
    __std_get_trap_command__ __std_original_debug_trap DEBUG || true
    __std_cleanup_int_trap_spec="__not-installed__"
    __std_cleanup_term_trap_spec="__not-installed__"
    __std_cleanup_debug_trap_spec="__not-installed__"
    trap '__std_run_cleanup_hooks__' EXIT
    __std_cleanup_dispatcher_trap_spec="$(trap -p EXIT || true)"
    trap '__std_cleanup_debug_guard__' DEBUG
    __std_cleanup_debug_trap_spec="$(trap -p DEBUG || true)"
    __std_cleanup_dispatcher_installed=1
    __std_cleanup_refresh_signal_traps__
    return 0
}

__std_maybe_uninstall_cleanup_dispatcher__() {
    local current_exit_trap_spec current_int_trap_spec
    local current_term_trap_spec current_debug_trap_spec

    ((__std_cleanup_dispatcher_installed)) || return 0
    if ((${#__std_cleanup_entries[@]})); then
        return 0
    fi

    __std_cleanup_debug_guard_running=1
    current_exit_trap_spec="$(trap -p EXIT || true)"
    if [[ "$current_exit_trap_spec" == "$__std_cleanup_dispatcher_trap_spec" ]]; then
        trap - EXIT
        __std_restore_trap_spec__ EXIT "$__std_original_exit_trap_spec"
    fi
    current_int_trap_spec="$(trap -p INT || true)"
    if [[ "$current_int_trap_spec" == "$__std_cleanup_int_trap_spec" ]]; then
        __std_restore_trap_spec__ INT "$__std_original_int_trap_spec"
    fi
    current_term_trap_spec="$(trap -p TERM || true)"
    if [[ "$current_term_trap_spec" == "$__std_cleanup_term_trap_spec" ]]; then
        __std_restore_trap_spec__ TERM "$__std_original_term_trap_spec"
    fi
    current_debug_trap_spec="$(trap -p DEBUG || true)"
    if [[ "$current_debug_trap_spec" == "$__std_cleanup_debug_trap_spec" ||
        "$current_debug_trap_spec" == *"__std_cleanup_debug_guard__"* ]]; then
        __std_restore_trap_spec__ DEBUG "$__std_original_debug_trap_spec"
    fi

    __std_cleanup_dispatcher_installed=0
    __std_cleanup_debug_guard_running=0
    __std_original_exit_trap=""
    __std_original_exit_trap_spec=""
    __std_cleanup_dispatcher_trap_spec=""
    __std_original_int_trap=""
    __std_original_int_trap_spec=""
    __std_cleanup_int_trap_spec="__not-installed__"
    __std_original_term_trap=""
    __std_original_term_trap_spec=""
    __std_cleanup_term_trap_spec="__not-installed__"
    __std_original_debug_trap=""
    __std_original_debug_trap_spec=""
    __std_cleanup_debug_trap_spec="__not-installed__"
    return 0
}

#
# std_register_cleanup_hook - Registers a function to run from the shared EXIT trap.
#
# Cleanup hooks run after any EXIT trap that existed before the first cleanup hook
# registration. Hooks are function names, not shell command strings.
#
# Usage:
#   cleanup_workspace() { rm -rf -- "$workspace"; }
#   std_register_cleanup_hook cleanup_workspace
#
std_register_cleanup_hook() {
    local hook="${1-}" existing_hook

    if (($# != 1)); then
        log_error -l base_bash_libs.std "std_register_cleanup_hook: expected exactly one function name."
        return 1
    fi
    if ! __is_valid_variable_name__ "$hook" || ! declare -F "$hook" >/dev/null; then
        log_error -l base_bash_libs.std "std_register_cleanup_hook: '$hook' is not a defined cleanup function."
        return 1
    fi

    for existing_hook in "${__std_cleanup_hooks[@]+"${__std_cleanup_hooks[@]}"}"; do
        [[ "$existing_hook" == "$hook" ]] && return 0
    done

    __std_cleanup_hooks+=("$hook")
    __std_cleanup_entries+=("hook:$hook")
    __std_install_cleanup_dispatcher__
    return 0
}

#
# std_unregister_cleanup_hook - Removes a function from the shared EXIT cleanup hook list.
#
# Usage:
#   std_unregister_cleanup_hook cleanup_workspace
#
std_unregister_cleanup_hook() {
    local hook="${1-}" existing_hook entry entry_type entry_value
    local -a remaining_hooks=() remaining_entries=()

    if (($# != 1)); then
        log_error -l base_bash_libs.std "std_unregister_cleanup_hook: expected exactly one function name."
        return 1
    fi

    for existing_hook in "${__std_cleanup_hooks[@]+"${__std_cleanup_hooks[@]}"}"; do
        [[ "$existing_hook" == "$hook" ]] && continue
        remaining_hooks+=("$existing_hook")
    done
    __std_cleanup_hooks=("${remaining_hooks[@]+"${remaining_hooks[@]}"}")
    for entry in "${__std_cleanup_entries[@]+"${__std_cleanup_entries[@]}"}"; do
        entry_type="${entry%%:*}"
        entry_value="${entry#*:}"
        if [[ "$entry_type" == hook && "$entry_value" == "$hook" ]]; then
            continue
        fi
        remaining_entries+=("$entry")
    done
    __std_cleanup_entries=("${remaining_entries[@]+"${remaining_entries[@]}"}")
    __std_maybe_uninstall_cleanup_dispatcher__
    return 0
}

__std_is_safe_cleanup_path__() {
    local path="${1-}"

    [[ -n "$path" ]] || return 1
    [[ "$path" == /* ]] || return 1
    [[ "$path" =~ ^/+$ ]] && return 1
    case "$path" in
        . | .. | */.. | */../* | */. | */./*)
            return 1
            ;;
    esac
    return 0
}

__std_is_broad_cleanup_path__() {
    local path="${1-}"
    local home_dir="${HOME:-}" tmp_dir="${TMPDIR:-}"

    [[ "$path" == "/" ]] && return 0
    [[ -n "$home_dir" && "$path" == "$home_dir" ]] && return 0
    [[ -n "$tmp_dir" && "$path" == "$tmp_dir" ]] && return 0
    case "$path" in
        /tmp | /var/tmp | /private/tmp | /private/var/tmp | \
        /bin | /bin/* | /sbin | /sbin/* | /usr | /usr/* | /etc | /etc/* | \
        /var | /System | /System/* | /Library | /Library/* | \
        /Applications | /Applications/* | /dev | /dev/*)
            return 0
            ;;
    esac
    return 1
}

#
# std_register_cleanup_path - Registers files or directories for removal at shell exit.
#
# Paths are removed with `rm -rf --` from the shared EXIT trap. Paths must be
# absolute so cleanup cannot drift when a script changes directory after
# registration. The normal form snapshots every path component (device and
# inode) at registration and refuses deletion if any component is replaced.
# `--unsafe` opts out of that identity proof for a specific path, but broad
# roots and system/shared directories remain rejected in all modes.
#
# Usage:
#   workspace="$(mktemp -d)"
#   std_register_cleanup_path "$workspace"
#   std_register_cleanup_path --unsafe "$legacy_path"
#
std_register_cleanup_path() {
    local path existing_path fingerprint
    local unsafe=0 already_registered had_valid_path=0 status=0

    if (($# == 0)); then
        log_warn -l base_bash_libs.std "std_register_cleanup_path: No paths provided."
        return 0
    fi

    if [[ "${1-}" == "--unsafe" ]]; then
        unsafe=1
        shift
    fi
    if [[ "${1-}" == "--" ]]; then
        shift
    fi
    if (($# == 0)); then
        log_warn -l base_bash_libs.std "std_register_cleanup_path: No paths provided."
        return 0
    fi

    for path; do
        if ! __std_is_safe_cleanup_path__ "$path"; then
            log_error -l base_bash_libs.std "std_register_cleanup_path: refusing to register unsafe cleanup path '$path'."
            status=1
            continue
        fi
        if __std_is_broad_cleanup_path__ "$path"; then
            log_error -l base_bash_libs.std "std_register_cleanup_path: refusing to register broad or protected path '$path'."
            status=1
            continue
        fi
        if (( ! unsafe )) && [[ -L "$path" ]]; then
            log_error -l base_bash_libs.std "std_register_cleanup_path: refusing to register symlink '$path' without --unsafe."
            status=1
            continue
        fi
        if (( ! unsafe )) && ! [[ -e "$path" ]]; then
            log_error -l base_bash_libs.std "std_register_cleanup_path: path '$path' does not exist for ownership proof."
            status=1
            continue
        fi

        had_valid_path=1
        already_registered=0
        for existing_path in "${__std_cleanup_paths[@]+"${__std_cleanup_paths[@]}"}"; do
            if [[ "$existing_path" == "$path" ]]; then
                already_registered=1
                break
            fi
        done
        if (( ! already_registered )); then
            if (( unsafe )); then
                fingerprint=UNSAFE
            elif ! __std_capture_cleanup_path_fingerprint__ fingerprint "$path"; then
                log_error -l base_bash_libs.std "std_register_cleanup_path: unable to snapshot ownership for '$path'."
                status=1
                continue
            fi
            __std_cleanup_paths+=("$path")
            __std_cleanup_entries+=("path:$path")
            __std_cleanup_path_fingerprints["$path"]="$fingerprint"
        fi
    done

    if ((had_valid_path)); then
        __std_install_cleanup_dispatcher__
    fi
    return "$status"
}

#
# std_unregister_cleanup_path - Removes files or directories from the shared EXIT cleanup path list.
#
# This is useful after eager cleanup removes or moves a path that was previously
# registered for fallback cleanup. Paths use the same safety checks as
# registration. Safe paths in a mixed call are still unregistered, and the
# function returns nonzero if any path was rejected.
#
# Usage:
#   rm -rf -- "$workspace"
#   std_unregister_cleanup_path "$workspace"
#
std_unregister_cleanup_path() {
    local path existing_path entry entry_type entry_value
    local should_remove had_valid_path=0 status=0
    local -a paths_to_remove=() remaining_paths=() remaining_entries=()

    if (($# == 0)); then
        log_warn -l base_bash_libs.std "std_unregister_cleanup_path: No paths provided."
        return 0
    fi

    for path; do
        if ! __std_is_safe_cleanup_path__ "$path"; then
            log_error -l base_bash_libs.std "std_unregister_cleanup_path: refusing to unregister unsafe cleanup path '$path'."
            status=1
            continue
        fi

        had_valid_path=1
        paths_to_remove+=("$path")
    done

    if ((had_valid_path)); then
        for existing_path in "${__std_cleanup_paths[@]+"${__std_cleanup_paths[@]}"}"; do
            should_remove=0
            for path in "${paths_to_remove[@]+"${paths_to_remove[@]}"}"; do
                if [[ "$existing_path" == "$path" ]]; then
                    should_remove=1
                    break
                fi
            done
            ((should_remove)) || remaining_paths+=("$existing_path")
        done
        __std_cleanup_paths=("${remaining_paths[@]+"${remaining_paths[@]}"}")
        for entry in "${__std_cleanup_entries[@]+"${__std_cleanup_entries[@]}"}"; do
            entry_type="${entry%%:*}"
            entry_value="${entry#*:}"
            should_remove=0
            if [[ "$entry_type" == path ]]; then
                for path in "${paths_to_remove[@]+"${paths_to_remove[@]}"}"; do
                    if [[ "$entry_value" == "$path" ]]; then
                        should_remove=1
                        break
                    fi
                done
            fi
            ((should_remove)) || remaining_entries+=("$entry")
        done
        __std_cleanup_entries=("${remaining_entries[@]+"${remaining_entries[@]}"}")
        for path in "${paths_to_remove[@]+"${paths_to_remove[@]}"}"; do
            unset "__std_cleanup_path_fingerprints[$path]"
        done
    fi

    __std_maybe_uninstall_cleanup_dispatcher__
    return "$status"
}

######################################################## TEMP FILES ####################################################

__std_make_temp_path__() {
    local __std_temp_helper_name="$1" __std_temp_path_kind="$2"
    shift 2
    local __std_temp_keep=0 __std_temp_result_name __std_temp_prefix __std_temp_root __std_temp_template __std_temp_path

    while (($#)); do
        case "${1-}" in
            --keep)
                __std_temp_keep=1
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                break
                ;;
        esac
    done

    if (($# < 1 || $# > 2)); then
        log_error -l base_bash_libs.std "$__std_temp_helper_name: usage: $__std_temp_helper_name [--keep] <result_variable_name> [prefix]"
        return 1
    fi

    __std_temp_result_name="$1"
    __std_temp_prefix="${2:-base-bash-libs}"

    if ! __is_valid_variable_name__ "$__std_temp_result_name"; then
        log_error -l base_bash_libs.std "$__std_temp_helper_name: result variable name must be a valid Bash variable name."
        return 1
    fi
    __std_assert_writable_output__ "$__std_temp_helper_name" "$__std_temp_result_name" || return 1
    if [[ -z "$__std_temp_prefix" || "$__std_temp_prefix" == */* ]]; then
        log_error -l base_bash_libs.std "$__std_temp_helper_name: prefix must be a non-empty filename prefix without '/'."
        return 1
    fi

    __std_temp_root="${TMPDIR:-/tmp}"
    if [[ "$__std_temp_root" != /* ]]; then
        if ! __std_temp_root="$(cd -- "$__std_temp_root" 2>/dev/null && pwd -P)"; then
            log_error -l base_bash_libs.std "$__std_temp_helper_name: TMPDIR is not a directory: ${TMPDIR:-/tmp}"
            return 1
        fi
    fi
    while [[ "$__std_temp_root" != "/" && "$__std_temp_root" == */ ]]; do
        __std_temp_root="${__std_temp_root%/}"
    done
    if [[ -z "$__std_temp_root" || ! -d "$__std_temp_root" ]]; then
        log_error -l base_bash_libs.std "$__std_temp_helper_name: TMPDIR is not a directory: ${TMPDIR:-/tmp}"
        return 1
    fi

    if [[ "$__std_temp_root" == "/" ]]; then
        __std_temp_template="/$__std_temp_prefix.XXXXXXXXXX"
    else
        __std_temp_template="$__std_temp_root/$__std_temp_prefix.XXXXXXXXXX"
    fi
    if [[ "$__std_temp_path_kind" == "dir" ]]; then
        __std_temp_path="$(mktemp -d "$__std_temp_template" 2>/dev/null)" || {
            log_error -l base_bash_libs.std "$__std_temp_helper_name: failed to create temporary directory."
            return 1
        }
    else
        __std_temp_path="$(mktemp "$__std_temp_template" 2>/dev/null)" || {
            log_error -l base_bash_libs.std "$__std_temp_helper_name: failed to create temporary file."
            return 1
        }
    fi

    if ((! __std_temp_keep)); then
        if ! std_register_cleanup_path "$__std_temp_path"; then
            rm -rf -- "$__std_temp_path"
            return 1
        fi
    fi

    printf -v "$__std_temp_result_name" '%s' "$__std_temp_path"
    return 0
}

#
# std_make_temp_file - Creates a temporary file and stores its path in a named variable.
#
# The created file is registered for exit cleanup unless `--keep` is provided.
#
# Usage:
#   std_make_temp_file [--keep] <result_variable_name> [prefix]
#
std_make_temp_file() {
    __std_preflight_temp_result_name__ std_make_temp_file "$@" || return 1
    __std_make_temp_path__ std_make_temp_file file "$@"
}

# Private counterpart for reserved implementation-local result variables.
# Public named-output helpers continue to reject the `__` namespace.
__std_make_internal_temp_file__() {
    __std_make_temp_path__ __std_make_internal_temp_file__ file "$@"
}

#
# std_make_temp_dir - Creates a temporary directory and stores its path in a named variable.
#
# The created directory is registered for exit cleanup unless `--keep` is provided.
#
# Usage:
#   std_make_temp_dir [--keep] <result_variable_name> [prefix]
#
std_make_temp_dir() {
    __std_preflight_temp_result_name__ std_make_temp_dir "$@" || return 1
    __std_make_temp_path__ std_make_temp_dir dir "$@"
}

# Private counterpart for reserved implementation-local result variables.
# Public named-output helpers continue to reject the `__` namespace.
__std_make_internal_temp_dir__() {
    __std_make_temp_path__ __std_make_internal_temp_dir__ dir "$@"
}

####################################################### ASSERTIONS ####################################################

__is_valid_variable_name__() {
    local __std_variable_name="${1-}"
    local __std_variable_name_re='^[A-Za-z_][A-Za-z0-9_]*$'
    [[ "$__std_variable_name" =~ $__std_variable_name_re ]]
}

__std_assert_writable_output__() {
    local __std_output_function_name="${1-}" __std_output_name="${2-}"
    local __std_output_declaration __std_output_attributes

    if [[ "$__std_output_name" == __* ]]; then
        case "$__std_output_function_name" in
            __std_make_internal_temp_file__ | __std_make_internal_temp_dir__) ;;
            *)
                log_error -l base_bash_libs.std \
                    "$__std_output_function_name: result variable '$__std_output_name' uses the reserved '__' internal namespace."
                return 1
                ;;
        esac
    fi

    __std_output_declaration="$(declare -p "$__std_output_name" 2>/dev/null || true)"
    [[ -n "$__std_output_declaration" ]] || return 0
    __std_output_attributes="${__std_output_declaration#declare -}"
    __std_output_attributes="${__std_output_attributes%% *}"
    if [[ "$__std_output_attributes" == *r* ]]; then
        log_error -l base_bash_libs.std \
            "$__std_output_function_name: result variable '$__std_output_name' is readonly."
        return 1
    fi
    return 0
}

__std_assert_public_variable_names__() {
    (($# >= 1)) || return 1
    set -- "${@:2}" "$1"

    while (($# > 1)); do
        if [[ "${1-}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ && "${1-}" == __* ]]; then
            log_error -l base_bash_libs.std \
                "${!#}: variable '${1-}' uses the reserved '__' internal namespace."
            return 1
        fi
        shift
    done
    return 0
}

__std_preflight_temp_result_name__() {
    (($# >= 1)) || return 1
    shift
    while (($#)); do
        case "${1-}" in
            --keep)
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                break
                ;;
        esac
    done
    (($# >= 1)) || return 0
    __std_assert_public_variable_names__ "${FUNCNAME[1]}" "${1-}"
}

#
# assert_variable_name - Verifies that one or more arguments are valid Bash variable names.
#
# This validates the names themselves. It does not require the named variables to
# exist or have non-empty values.
#
# Usage:
#   assert_variable_name result_name array_name
#
assert_variable_name() {
    local __std_assert_variable_name

    if (($# == 0)); then
        fatal_error "assert_variable_name: No variable names provided for validation."
    fi

    for __std_assert_variable_name in "$@"; do
        if ! __is_valid_variable_name__ "$__std_assert_variable_name"; then
            fatal_error "assert_variable_name expects valid Bash variable names; one or more arguments are invalid."
        fi
    done

    return 0
}

__std_declares_array_kind__() {
    local __std_array_variable_name="${1-}" __std_array_kind="${2-}"
    local __std_array_declaration __std_array_attributes

    __std_array_declaration="$(declare -p "$__std_array_variable_name" 2>/dev/null)" || return 1
    __std_array_attributes="${__std_array_declaration#declare -}"
    __std_array_attributes="${__std_array_attributes%% *}"
    [[ "$__std_array_attributes" == *"$__std_array_kind"* ]]
}

#
# assert_indexed_array - Verifies that one or more variables are declared indexed arrays.
#
# This validates that callers declared the named variables with indexed-array
# semantics before passing them to helpers that mutate or read arrays in place.
#
# Usage:
#   declare -a values=()
#   assert_indexed_array values
#
assert_indexed_array() {
    if (($# == 0)); then
        fatal_error "assert_indexed_array: No variable names provided for validation."
    fi
    __std_assert_public_variable_names__ assert_indexed_array "$@" || return 1
    local __std_assert_indexed_name

    for __std_assert_indexed_name in "$@"; do
        assert_variable_name "$__std_assert_indexed_name"
        if ! __std_declares_array_kind__ "$__std_assert_indexed_name" "a"; then
            fatal_error "Variable '$__std_assert_indexed_name' must be an indexed array declared by the caller."
        fi
    done

    return 0
}

#
# assert_associative_array - Verifies that one or more variables are declared associative arrays.
#
# This validates that callers declared the named variables with associative-array
# semantics before passing them to helpers that mutate or read maps in place.
#
# Usage:
#   declare -A options=()
#   assert_associative_array options
#
assert_associative_array() {
    if (($# == 0)); then
        fatal_error "assert_associative_array: No variable names provided for validation."
    fi
    __std_assert_public_variable_names__ assert_associative_array "$@" || return 1
    local __std_assert_associative_name

    for __std_assert_associative_name in "$@"; do
        assert_variable_name "$__std_assert_associative_name"
        if ! __std_declares_array_kind__ "$__std_assert_associative_name" "A"; then
            fatal_error "Variable '$__std_assert_associative_name' must be an associative array declared by the caller."
        fi
    done

    return 0
}

##################################################### INTROSPECTION ###################################################

#
# std_command_path - Resolves an external command path without exiting the caller.
#
# Usage:
#   if std_command_path git_path git; then
#       std_run "$git_path" status --short
#   fi
#
std_command_path() {
    if (($# != 2)); then
        log_error -l base_bash_libs.std "std_command_path: usage: std_command_path <result_variable_name> <command_name>"
        return 1
    fi
    __std_assert_public_variable_names__ std_command_path "${1-}" || return 1
    local __std_command_result_name="$1" __std_command_name="$2" __std_command_resolved_path=""

    if ! __is_valid_variable_name__ "$__std_command_result_name"; then
        log_error -l base_bash_libs.std "std_command_path: result variable name must be a valid Bash variable name."
        return 1
    fi
    __std_assert_writable_output__ std_command_path "$__std_command_result_name" || return 1

    if [[ -n "$__std_command_name" ]]; then
        __std_command_resolved_path="$(type -P "$__std_command_name" 2>/dev/null || true)"
    fi
    printf -v "$__std_command_result_name" '%s' "$__std_command_resolved_path"
    [[ -n "$__std_command_resolved_path" ]]
}

#
# std_function_exists - Checks whether a Bash function is currently defined.
#
std_function_exists() {
    local function_name="${1-}"

    (($# == 1)) || return 1
    __is_valid_variable_name__ "$function_name" || return 1
    declare -F "$function_name" >/dev/null
}

#
# assert_function_exists - Verifies that one or more Bash functions are defined.
#
# Usage:
#   assert_function_exists main cleanup_workspace
#
assert_function_exists() {
    local missing_functions=() function_name

    if (($# == 0)); then
        fatal_error "assert_function_exists: No function names provided for validation."
    fi

    for function_name in "$@"; do
        if ! __is_valid_variable_name__ "$function_name"; then
            fatal_error "assert_function_exists expects function names; one or more arguments are not valid Bash function names."
        fi
        if ! std_function_exists "$function_name"; then
            missing_functions+=("$function_name")
        fi
    done

    if [[ -n "${missing_functions[0]+set}" ]]; then
        fatal_error "Required functions are not defined: ${missing_functions[*]}"
    fi

    return 0
}

#
# assert_not_null - Checks that one or more variables are not empty.
#
# This function takes the *name* of one or more variables and checks that
# each one has a non-empty value. It is useful for validating required
# script inputs or configuration variables. Unlike other assertions, it
# checks all provided variables and reports all failures at once.
#
# Usage:
#   USER="admin"
#   TOKEN=""
#   assert_not_null USER       # This will succeed.
#   assert_not_null USER TOKEN # This will fail, listing TOKEN as empty.
#   assert_not_null "$TOKEN"   # Wrong: pass variable names, not values.
#
# Arguments:
#   $@: One or more variable names to check.
#
assert_not_null() {
    if (($# == 0)); then
        fatal_error "assert_not_null: No variable names provided for validation."
    fi
    __std_assert_public_variable_names__ assert_not_null "$@" || return 1
    local -a __std_assert_not_null_unset_names=()
    local __std_assert_not_null_name

    for __std_assert_not_null_name in "$@"; do
        if ! __is_valid_variable_name__ "$__std_assert_not_null_name"; then
            fatal_error "assert_not_null expects variable names, not values; one or more arguments are not valid Bash variable names."
        fi
        # Use indirection to get the value of the variable whose name is stored in var_name.
        # The -v check is for unset variables, -z is for empty strings.
        # We check for empty string as per the request.
        if [[ ! -v $__std_assert_not_null_name || -z "${!__std_assert_not_null_name-}" ]]; then
            __std_assert_not_null_unset_names+=("$__std_assert_not_null_name")
        fi
    done

    if [[ -n "${__std_assert_not_null_unset_names[0]+set}" ]]; then
        fatal_error "These required variables are not set or are empty: ${__std_assert_not_null_unset_names[*]}"
    fi

    return 0
}

#
# assert_integer - Checks if the values of one or more variables are valid integers.
#
__std_assert_integer_names__() {
    local __std_assert_integer_name __std_assert_integer_value
    local __std_assert_integer_re='^[-+]?[0-9]+$'
    for __std_assert_integer_name in "$@"; do
        if ! __is_valid_variable_name__ "$__std_assert_integer_name"; then
            fatal_error "assert_integer expects variable names, not values; one or more arguments are not valid Bash variable names."
        fi
        __std_assert_integer_value="${!__std_assert_integer_name-}"
        ! [[ "$__std_assert_integer_value" =~ $__std_assert_integer_re ]] &&
            fatal_error "Variable '$__std_assert_integer_name' with value '$__std_assert_integer_value' is not a valid integer."
    done
    return 0
}

assert_integer() {
    (($# == 0)) && fatal_error "assert_integer: No variable names provided."
    __std_assert_public_variable_names__ assert_integer "$@" || return 1
    __std_assert_integer_names__ "$@"
}

#
# assert_integer_range - Checks if a variable's value is an integer within a specified range.
#
# Arguments:
#   $1: The NAME of the variable to check.
#   $2: The minimum value.
#   $3: The maximum value.
#
assert_integer_range() {
    (($# != 3)) && fatal_error "assert_integer_range: Expected 3 arguments, got $#."
    __std_assert_public_variable_names__ assert_integer_range "${1-}" || return 1
    local __std_range_name="$1" __std_range_min="$2" __std_range_max="$3"
    local __std_range_value __std_range_value_number __std_range_min_number __std_range_max_number
    if ! __is_valid_variable_name__ "$__std_range_name"; then
        fatal_error "assert_integer_range expects a variable name as its first argument."
    fi
    if ! [[ "$__std_range_min" =~ ^[-+]?[0-9]+$ ]]; then
        fatal_error "assert_integer_range minimum bound '$__std_range_min' is not a valid integer."
    fi
    if ! [[ "$__std_range_max" =~ ^[-+]?[0-9]+$ ]]; then
        fatal_error "assert_integer_range maximum bound '$__std_range_max' is not a valid integer."
    fi
    __std_range_value="${!__std_range_name-}"
    __std_assert_integer_names__ "$__std_range_name"
    __std_decimal_integer_value__ __std_range_value_number "$__std_range_value"
    __std_decimal_integer_value__ __std_range_min_number "$__std_range_min"
    __std_decimal_integer_value__ __std_range_max_number "$__std_range_max"
    ((__std_range_min_number > __std_range_max_number)) &&
        fatal_error "assert_integer_range minimum '$__std_range_min' cannot exceed maximum '$__std_range_max'."
    ((__std_range_value_number < __std_range_min_number || __std_range_value_number > __std_range_max_number)) &&
        fatal_error "Variable '$__std_range_name' ($__std_range_value) is out of range [$__std_range_min, $__std_range_max]."
    return 0
}

#
# assert_arg_count - Checks that the number of arguments falls within a given range.
#
# Usage:
#   assert_arg_count $# 2      # Fails if arg count is not exactly 2
#   assert_arg_count $# 1 3    # Fails if arg count is not between 1 and 3 (inclusive)
#
# Arguments:
#   $1: The actual number of arguments (typically $#).
#   $2: The exact expected count, or the minimum count for a range.
#   $3: (Optional) The maximum count for a range.
#
assert_arg_count() {
    local __std_arg_count_actual="${1-}" __std_arg_count_first="${2-}" __std_arg_count_second="${3-}"
    local __std_arg_count_arity=$#

    # Check the number of arguments passed to this function itself.
    if ((__std_arg_count_arity < 2 || __std_arg_count_arity > 3)); then
        fatal_error "assert_arg_count: Incorrect usage. Expected 2 or 3 arguments, but got $__std_arg_count_arity."
    fi

    # Create temporary named variables for assert_integer to check
    local __std_arg_count_actual_value="$__std_arg_count_actual" __std_arg_count_first_value="$__std_arg_count_first"
    local __std_arg_count_actual_number __std_arg_count_first_number __std_arg_count_second_number
    __std_assert_integer_names__ __std_arg_count_actual_value __std_arg_count_first_value

    if [[ -n "$__std_arg_count_second" ]]; then
        local __std_arg_count_second_value="$__std_arg_count_second"
        __std_assert_integer_names__ __std_arg_count_second_value
    fi

    __std_decimal_integer_value__ __std_arg_count_actual_number "$__std_arg_count_actual"
    __std_decimal_integer_value__ __std_arg_count_first_number "$__std_arg_count_first"
    if [[ -n "$__std_arg_count_second" ]]; then
        __std_decimal_integer_value__ __std_arg_count_second_number "$__std_arg_count_second"
        ((__std_arg_count_first_number > __std_arg_count_second_number)) &&
            fatal_error "assert_arg_count minimum '$__std_arg_count_first' cannot exceed maximum '$__std_arg_count_second'."
    fi

    if [[ -z "$__std_arg_count_second" ]]; then
        # Exact match case
        if ((__std_arg_count_actual_number != __std_arg_count_first_number)); then
            fatal_error "Argument count mismatch: expected $__std_arg_count_first but got $__std_arg_count_actual arguments"
        fi
    else
        # Range match case
        if ((__std_arg_count_actual_number < __std_arg_count_first_number ||
            __std_arg_count_actual_number > __std_arg_count_second_number)); then
            fatal_error "Argument count mismatch: expected between $__std_arg_count_first and $__std_arg_count_second arguments, but got $__std_arg_count_actual"
        fi
    fi
    return 0
}

#
# assert_command_exists - Checks that one or more commands are available in the system's PATH.
#
# This function iterates through all provided command names and uses 'command -v'
# to verify their existence. If any command is not found, it collects the names
# and reports them all in a single fatal error.
#
# Usage:
#   assert_command_exists git curl jq
#
# Arguments:
#   $@: One or more command names to check.
#
assert_command_exists() {
    local missing_commands=()
    local cmd

    if (($# == 0)); then
        log_warn -l base_bash_libs.std "assert_command_exists: No commands provided to check."
        return 0
    fi

    for cmd; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done

    if [[ -n "${missing_commands[0]+set}" ]]; then
        fatal_error "These required commands were not found in your PATH: ${missing_commands[*]}"
    fi

    return 0
}

#
# assert_file_exists - Checks that one or more paths exist and are regular files.
#
# This function iterates through all provided paths. If any path does not
# exist or is not a regular file (e.g., it's a directory or a symlink to
# a non-file), it collects the names and reports them all in a single fatal error.
#
# Usage:
#   assert_file_exists "/etc/hosts" "./my_script.sh"
#
# Arguments:
#   $@: One or more file paths to check.
#
assert_file_exists() {
    local missing_files=()
    local file

    if (($# == 0)); then
        log_warn -l base_bash_libs.std "assert_file_exists: No files provided to check."
        return 0
    fi

    for file; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done

    if [[ -n "${missing_files[0]+set}" ]]; then
        fatal_error "These required files do not exist or are not regular files: ${missing_files[*]}"
    fi

    return 0
}

#
# assert_executable - Checks that one or more paths exist and are executable files.
#
# This function iterates through all provided paths. If any path does not
# exist, is not a regular file, or is not executable, it collects the names
# and reports them all in a single fatal error.
#
# Use this for explicit paths such as project-local scripts. Use
# `assert_command_exists` when checking whether a command is discoverable
# through PATH.
#
# Usage:
#   assert_executable "./bin/tool" "/opt/vendor/bin/tool"
#
# Arguments:
#   $@: One or more executable file paths to check.
#
assert_executable() {
    local missing_executables=()
    local executable

    if (($# == 0)); then
        log_warn -l base_bash_libs.std "assert_executable: No executable paths provided to check."
        return 0
    fi

    for executable; do
        if [[ ! -f "$executable" || ! -x "$executable" ]]; then
            missing_executables+=("$executable")
        fi
    done

    if [[ -n "${missing_executables[0]+set}" ]]; then
        fatal_error "These required executable paths do not exist, are not regular files, or are not executable: ${missing_executables[*]}"
    fi

    return 0
}

#
# assert_dir_exists - Checks that one or more paths exist and are directories.
#
# This function iterates through all provided paths. If any path does not
# exist or is not a directory, it collects the names and reports them all
# in a single fatal error.
#
# Usage:
#   assert_dir_exists "/tmp" "/var/log"
#
# Arguments:
#   $@: One or more directory paths to check.
#
assert_dir_exists() {
    local missing_dirs=()
    local dir

    if (($# == 0)); then
        log_warn -l base_bash_libs.std "assert_dir_exists: No directories provided to check."
        return 0
    fi

    for dir;  do
        if [[ ! -d "$dir" ]]; then
            missing_dirs+=("$dir")
        fi
    done

    if [[ -n "${missing_dirs[0]+set}" ]]; then
        fatal_error "These required directories do not exist: ${missing_dirs[*]}"
    fi

    return 0
}

################################################# MISC FUNCTIONS #######################################################

#
# safe_cd - A safe version of the 'cd' command that exits on failure.
#
safe_cd() {
    local dir="${1-}"
    [[ "$dir" ]] || fatal_error "No arguments or an empty string passed to safe_cd"
    cd -- "$dir" || fatal_error "Can't cd to '$dir'"
}

#
# safe_unalias - Safely unaliases a command, without erroring if it doesn't exist.
#
safe_unalias() {
    # Ref: https://stackoverflow.com/a/61471333/6862601
    local alias_name
    for alias_name; do
        [[ ${BASH_ALIASES[$alias_name]-} ]] && unalias "$alias_name"
    done
    return 0
}

#
# get_my_source_dir - Returns the absolute path to the directory of the calling script through the passed variable name.
#
# Usage:
#   get_my_source_dir var_name
#
get_my_source_dir() {
    [[ -n "${1-}" ]] || fatal_error "get_my_source_dir: No result variable name provided."
    __std_assert_public_variable_names__ get_my_source_dir "${1-}" || return 1
    local __std_source_result_name="$1"

    if ! __is_valid_variable_name__ "$__std_source_result_name"; then
        fatal_error "get_my_source_dir: result variable name must be a valid Bash variable name."
    fi
    __std_assert_writable_output__ get_my_source_dir "$__std_source_result_name" || return 1
    local __std_source_dir __std_source_path="${BASH_SOURCE[1]-}"
    # Reference: https://stackoverflow.com/a/246128/6862601
    if [[ -n "$__std_source_path" ]]; then
        __std_source_dir="$(cd "$(dirname -- "$__std_source_path")" >/dev/null 2>&1 && pwd -P)" ||
            fatal_error "get_my_source_dir: Unable to resolve source directory."
    else
        __std_source_dir="$(pwd -P)" || fatal_error "get_my_source_dir: Unable to resolve source directory."
    fi
    printf -v "$__std_source_result_name" '%s' "$__std_source_dir"
}

#
# ask_yes_no - Get user's confirmation
#
# Prompts the user with a given message for a yes/no answer and returns 0 or 1
# based on user's choice of yes or no. It reads a single character without
# requiring the user to press Enter.
#
# Arguments:
#   $1: The message string to display as the prompt.
#
# Usage:
#
#   if ask_yes_no "Do you want to continue?"; then
#       echo "User chose to continue."
#   else
#       echo "User chose not to continue."
#   fi
#
ask_yes_no() {
    if (("$#" != 1)); then
        log_error -l base_bash_libs.std "ask_yes_no: invalid arguments"
        log_info -l base_bash_libs.std "Usage: ask_yes_no <prompt_message>"
        return 1
    fi

    local message=$1 user_input tty_fd
    if ! exec {tty_fd}</dev/tty 2>/dev/null; then
        log_error -l base_bash_libs.std "ask_yes_no: /dev/tty is not available"
        return 1
    fi

    while true; do
        # Prompt the user for input.
        # -n 1: Reads only one character.
        # -r: Prevents backslash from acting as an escape character.
        # -p: Displays the prompt string.
        # The text "[y/N]" suggests that 'N' is the default choice.
        if ! read -r -n 1 -p "$message [y/N]: " user_input <&"$tty_fd"; then
            exec {tty_fd}<&-
            echo
            return 1
        fi

        # Add a newline since the user won't press Enter.
        echo

        case "$user_input" in
            [yY])
                exec {tty_fd}<&-
                return 0
                ;;
            [nN])
                exec {tty_fd}<&-
                return 1
                ;;
            *) echo "Invalid input. Please enter 'y' or 'n'.";;
        esac
    done
}

#
# wait_for_enter - Pauses the script and waits for the user to press the Enter key.
#
# Arguments:
#   $1: (Optional) The prompt to display. Defaults to "Press Enter to continue".
#
wait_for_enter() {
    if (("$#" > 1)); then
        log_error -l base_bash_libs.std "wait_for_enter: invalid arguments"
        log_info -l base_bash_libs.std "Usage: wait_for_enter [prompt_message]"
        return 1
    fi

    local prompt=${1:-"Press Enter to continue"} tty_fd read_status
    if ! exec {tty_fd}</dev/tty 2>/dev/null; then
        log_error -l base_bash_libs.std "wait_for_enter: /dev/tty is not available"
        return 1
    fi

    if read -r -s -p "$prompt" <&"$tty_fd"; then
        read_status=0
    else
        read_status=$?
    fi
    exec {tty_fd}<&-

    if ((read_status != 0)); then
        log_error -l base_bash_libs.std "wait_for_enter: failed to read from /dev/tty"
        return "$read_status"
    fi

    return 0
}

#################################################### END OF FUNCTIONS ##################################################
