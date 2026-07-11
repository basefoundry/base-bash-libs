# shellcheck shell=bash
#
# lib_file.sh - Bash library of generic file manipulation functions.
#

[[ -n "${__lib_file_sourced__:-}" ]] && return 0
if [[ "${BASE_BASH_LIBS_STDLIB_LOADED:-}" != "1" ]]; then
    printf '%s\n' "Error: lib_file.sh requires lib_std.sh to be sourced first." >&2
    return 1 2>/dev/null || exit 1
fi
readonly __lib_file_sourced__=1

__file_mode__() {
    local file_path="$1" mode

    if mode=$(stat -c '%a' "$file_path" 2>/dev/null); then
        printf '%s\n' "$mode"
        return 0
    fi

    stat -f '%Lp' "$file_path"
}

__preserve_file_mode__() {
    local source_file="$1" target_file="$2" source_mode

    if ! source_mode="$(__file_mode__ "$source_file")"; then
        return 1
    fi

    chmod "$source_mode" "$target_file"
}

__file_remove_temp_paths__() {
    local path

    for path; do
        [[ -n "$path" ]] && rm -f -- "$path"
    done
    return 0
}

__file_make_target_temp__() {
    local result_name="$1" target_file="$2"
    local target_dir target_base temp_dir temp_path

    target_dir="$(dirname -- "$target_file")"
    target_base="$(basename -- "$target_file")"
    temp_dir="$(cd -- "$target_dir" && pwd -P)" || return 1

    temp_path="$(mktemp "$temp_dir/$target_base.XXXXXX" 2>/dev/null)" || return 1
    if ! std_register_cleanup_path "$temp_path"; then
        rm -f -- "$temp_path"
        return 1
    fi

    printf -v "$result_name" '%s' "$temp_path"
}

__file_section_markers_ordered__() {
    local target_file="$1" beginning_marker="$2" end_marker="$3"

    awk -v START_M="$beginning_marker" -v END_M="$end_marker" '
    BEGIN {
        in_section = 0
        invalid = 0
    }
    $0 == START_M {
        if (in_section == 1) {
            invalid = 1
            exit
        }
        in_section = 1
        next
    }
    $0 == END_M {
        if (in_section == 0) {
            invalid = 1
            exit
        }
        in_section = 0
        next
    }
    END {
        if (in_section == 1) {
            invalid = 1
        }
        exit invalid
    }
    ' "$target_file"
}

__file_section_marker_counts__() {
    local target_file="$1" beginning_marker="$2" end_marker="$3"
    local beginning_count_var="$4" end_count_var="$5"
    local section_beginning_marker_count section_end_marker_count

    section_beginning_marker_count=$(grep -cxF -- "$beginning_marker" "$target_file" || true)
    section_end_marker_count=$(grep -cxF -- "$end_marker" "$target_file" || true)

    printf -v "$beginning_count_var" '%s' "$section_beginning_marker_count"
    printf -v "$end_count_var" '%s' "$section_end_marker_count"

    if ((section_beginning_marker_count != section_end_marker_count)); then
        log_error "Asymmetric markers in '$target_file': $section_beginning_marker_count start, $section_end_marker_count end. Manual repair needed."
        return 2
    fi
    if ((section_beginning_marker_count > 0)) && ! __file_section_markers_ordered__ "$target_file" "$beginning_marker" "$end_marker"; then
        log_error "Misordered markers in '$target_file'. Manual repair needed."
        return 2
    fi

    return 0
}

#
# file_section_exists - Inspect whether a marker-delimited section is present.
#
# Returns:
#   0 when the target file contains at least one valid marker pair.
#   1 when the target file is missing or the marker pair is absent.
#   2 when marker pairs are asymmetric or misordered and need manual repair.
#
file_section_exists() {
    if [[ $# -ne 3 ]]; then
        log_error "file_section_exists: expected <target_file> <beginning_marker> <end_marker>."
        return 2
    fi

    local target_file="$1" beginning_marker="$2" end_marker="$3"
    local beginning_marker_count _end_marker_count

    [[ -f "$target_file" ]] || return 1
    __file_section_marker_counts__ "$target_file" "$beginning_marker" "$end_marker" \
        beginning_marker_count _end_marker_count || return $?

    ((beginning_marker_count > 0))
}

#
# file_section_needs_update - Inspect whether add/update would change a section.
#
# Returns:
#   0 when adding or updating the section would change the target file.
#   1 when the first existing marker-delimited section already matches.
#   2 when marker pairs are asymmetric or misordered and need manual repair.
#
file_section_needs_update() {
    if [[ $# -lt 3 ]]; then
        log_error "file_section_needs_update: expected <target_file> <beginning_marker> <end_marker> [content_lines...]."
        return 2
    fi

    local target_file="$1" beginning_marker="$2" end_marker="$3"
    local beginning_marker_count _end_marker_count
    local current_content_file="" new_content_file="" status=0
    shift 3

    [[ -f "$target_file" ]] || return 0
    __file_section_marker_counts__ "$target_file" "$beginning_marker" "$end_marker" \
        beginning_marker_count _end_marker_count || return $?
    ((beginning_marker_count > 0)) || return 0

    if ! std_make_temp_file new_content_file base-file-section-new; then
        log_error "Failed to create temporary content file for '$target_file'."
        return 2
    fi
    if (($# > 0)); then
        if ! printf '%s\n' "$@" > "$new_content_file"; then
            log_error "Failed to write replacement content for '$target_file'."
            __file_remove_temp_paths__ "$new_content_file"
            return 2
        fi
    elif ! : > "$new_content_file"; then
        log_error "Failed to write replacement content for '$target_file'."
        __file_remove_temp_paths__ "$new_content_file"
        return 2
    fi

    if ! std_make_temp_file current_content_file base-file-section-current; then
        log_error "Failed to create temporary current content file for '$target_file'."
        __file_remove_temp_paths__ "$new_content_file"
        return 2
    fi

    if ! awk -v START_M="$beginning_marker" -v END_M="$end_marker" '
    BEGIN {
        in_section = 0
        processed = 0
    }
    $0 == START_M && processed == 0 {
        in_section = 1
        next
    }
    $0 == END_M && in_section == 1 {
        processed = 1
        exit
    }
    in_section == 1 {
        print $0
    }
    END {
        if (processed == 0) {
            exit 1
        }
    }
    ' "$target_file" > "$current_content_file"; then
        log_error "Failed to read existing section in '$target_file'."
        __file_remove_temp_paths__ "$current_content_file" "$new_content_file"
        return 2
    fi

    if cmp -s "$current_content_file" "$new_content_file"; then
        status=1
    fi

    __file_remove_temp_paths__ "$current_content_file" "$new_content_file"
    return "$status"
}

#
# update_file_section - Idempotently manages a block of text within a file,
#                       demarcated by start and end markers.
#
# This function can add, update, or remove a section of text in a file.
# It is designed to be safe to run multiple times. If the section already
# exists, the first full-line marker pair will be replaced. If it doesn't
# exist, it will be appended. If the target file itself does not exist, this
# returns success without creating the file.
#
# Usage:
#   update_file_section [options] <target_file> <start_marker> <end_marker> [content_lines...]
#
# Options:
#   -r : Remove the section defined by the markers instead of adding/updating it.
#
# Arguments:
#   target_file:    The path to the file to be modified.
#   start_marker:   The exact string that marks the beginning of the section.
#   end_marker:     The exact string that marks the end of the section.
#   content_lines:  (Optional) One or more strings, each representing a line of
#                   content to be placed inside the section.
#
# Examples:
#
#   # Add/update a section in .bash_profile
#   local commands=("export FOO=bar" "alias myalias='echo hello'")
#   update_file_section ~/.bash_profile "# START" "# END" "${commands[@]}"
#
#   # Remove the same section
#   update_file_section -r ~/.bash_profile "# START" "# END"
#
update_file_section() {
    local remove_section=false
    local new_content_array=()

    if [[ "$1" == "-r" ]]; then
        remove_section=true
        shift # consume -r
    fi

    if [[ $# -lt 3 ]]; then
        log_error "Insufficient arguments."
        if [[ "$remove_section" == true ]]; then
            log_info "Usage: update_file_section -r <target_file> <beginning_marker> <end_marker>"
        else
            log_info "Usage: update_file_section <target_file> <beginning_marker> <end_marker> [new_lines...]"
        fi
        return 1
    fi

    local target_file="$1" beginning_marker="$2" end_marker="$3"
    shift 3 # consume target_file, beginning_marker, end_marker
    if [[ "$remove_section" == true ]]; then
        if [[ $# -gt 0 ]]; then
            log_error "When -r flag is used, no content arguments should be provided."
            log_info "Usage: update_file_section -r <target_file> <beginning_marker> <end_marker>"
            return 1
        fi
    else
        new_content_array=("$@") # Capture remaining arguments as new_lines
    fi

    if [[ ! -f "$target_file" ]]; then
        log_debug "Target file '$target_file' does not exist."
        return 0
    fi

    local __file_update_beginning_marker_count __file_update_end_marker_count
    if ! __file_section_marker_counts__ "$target_file" "$beginning_marker" "$end_marker" \
        __file_update_beginning_marker_count __file_update_end_marker_count; then
        return 1
    fi

    local section_exists=false
    if ((__file_update_beginning_marker_count > 0)); then
        section_exists=true
    fi

    local new_content_string=""
    if [[ "$remove_section" == false ]]; then
        if [[ ${#new_content_array[@]} -gt 0 ]]; then
            # Use printf to join array elements with newlines, adding a final newline.
            # This ensures proper multi-line insertion.
            printf -v new_content_string '%s\n' "${new_content_array[@]}"
        fi
    fi

    if [[ "$section_exists" == false && "$remove_section" == true ]]; then
        log_debug "Section not present in '$target_file'; nothing to remove."
        return 0
    fi

    local current_content_file="" new_content_file="" temp_file
    if [[ "$remove_section" == false ]]; then
        if ! std_make_temp_file new_content_file base-file-section-new; then
            log_error "Failed to create temporary content file for '$target_file'."
            return 1
        fi

        if ! printf '%s' "$new_content_string" > "$new_content_file"; then
            log_error "Failed to write replacement content for '$target_file'."
            __file_remove_temp_paths__ "$new_content_file"
            return 1
        fi
    fi

    if [[ "$section_exists" == true && "$remove_section" == false ]]; then
        if ! std_make_temp_file current_content_file base-file-section-current; then
            log_error "Failed to create temporary current content file for '$target_file'."
            __file_remove_temp_paths__ "$new_content_file"
            return 1
        fi

        if ! awk -v START_M="$beginning_marker" -v END_M="$end_marker" '
        BEGIN {
            in_section = 0
            processed = 0
        }
        $0 == START_M && processed == 0 {
            in_section = 1
            next
        }
        $0 == END_M && in_section == 1 {
            processed = 1
            exit
        }
        in_section == 1 {
            print $0
        }
        ' "$target_file" > "$current_content_file"; then
            log_error "Failed to read existing section in '$target_file'."
            __file_remove_temp_paths__ "$current_content_file" "$new_content_file"
            return 1
        fi

        if cmp -s "$current_content_file" "$new_content_file"; then
            log_debug "Section already up to date in '$target_file'."
            __file_remove_temp_paths__ "$current_content_file" "$new_content_file"
            return 0
        fi
        __file_remove_temp_paths__ "$current_content_file"
    fi

    if [[ "$section_exists" == true ]]; then
        log_info "Updating '$target_file'"
    else
        log_info "Adding section to '$target_file'"
    fi
    if ! __file_make_target_temp__ temp_file "$target_file"; then
        log_error "Failed to create temporary file for '$target_file'."
        __file_remove_temp_paths__ "$new_content_file"
        return 1
    fi
    if ! __preserve_file_mode__ "$target_file" "$temp_file"; then
        log_error "Failed to preserve permissions for '$target_file'."
        __file_remove_temp_paths__ "$temp_file" "$new_content_file"
        return 1
    fi

    if [[ "$section_exists" == true ]]; then
        if [[ "$remove_section" == true ]]; then
            if awk -v START_M="$beginning_marker" -v END_M="$end_marker" '
            BEGIN {
                in_section = 0
                processed = 0
            }
            $0 == START_M && processed == 0 { in_section = 1; next }
            $0 == END_M && in_section == 1 {
                in_section = 0
                processed = 1
                next
            }
            {
                if (in_section == 0) {
                    print $0
                }
            }
            ' "$target_file" > "$temp_file" && mv -f "$temp_file" "$target_file"; then
                __file_remove_temp_paths__ "$new_content_file"
                return 0
            fi
        else
            if awk -v START_M="$beginning_marker" -v END_M="$end_marker" -v NEW_TEXT_FILE="$new_content_file" '
            BEGIN {
                processed = 0 # 0 = not yet processed, 1 = processing, 2 = done
            }
            $0 == START_M && processed == 0 {
                print START_M
                while ((getline line < NEW_TEXT_FILE) > 0) {
                    print line
                }
                close(NEW_TEXT_FILE)
                processed = 1 # We are now inside the section to be replaced
                next
            }
            $0 == END_M && processed == 1 {
                print END_M
                processed = 2 # We are done with the replacement
                next
            }
            processed != 1 { # Print the line if we are not inside the section being replaced
                print $0
            }
            ' "$target_file" > "$temp_file" && mv -f "$temp_file" "$target_file"; then
                __file_remove_temp_paths__ "$new_content_file"
                return 0
            fi
        fi

        log_error "Failed to process sections in '$target_file'."
        __file_remove_temp_paths__ "$temp_file" "$new_content_file"
        return 1
    else
        # Markers not found in the file
        if ! cp "$target_file" "$temp_file"; then
            log_error "Failed to copy '$target_file' to '$temp_file'."
            __file_remove_temp_paths__ "$temp_file" "$new_content_file"
            return 1
        fi

        if [[ -s "$temp_file" ]] && [[ $(tail -c 1 "$temp_file" 2>/dev/null | wc -l) -eq 0 ]]; then
            if ! printf '\n' >> "$temp_file"; then
                log_error "Failed to add trailing newline to '$temp_file'."
                __file_remove_temp_paths__ "$temp_file" "$new_content_file"
                return 1
            fi
        fi

        if ! {
            printf '%s\n' "$beginning_marker"
            printf '%s' "$new_content_string"
            printf '%s\n' "$end_marker"
        } >> "$temp_file"; then
            log_error "Failed to add new section to '$target_file'."
            __file_remove_temp_paths__ "$temp_file" "$new_content_file"
            return 1
        fi

        if ! mv -f "$temp_file" "$target_file"; then
            log_error "Failed to replace '$target_file' with '$temp_file'."
            __file_remove_temp_paths__ "$temp_file" "$new_content_file"
            return 1
        fi

        __file_remove_temp_paths__ "$new_content_file"
        return 0
    fi
}
