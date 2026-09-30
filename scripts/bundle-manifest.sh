#!/usr/bin/env bash

# Shared validation for paths named by MANIFEST.sha256 files. Callers retain
# responsibility for reporting the context-specific failure message.

bundle_manifest_path_is_safe() {
    local path="${1-}"

    [[ "$path" =~ ^[A-Za-z0-9_./-]+$ ]] || return 1
    [[ -n "$path" && "$path" != /* && "$path" != */ && "$path" != *//* ]] || return 1
    case "$path" in
    . | .. | ./* | ../* | */./* | */../* | */. | */..)
        return 1
        ;;
    esac
}

bundle_manifest_path_has_no_symlink_component() {
    local root="$1" relative="$2" candidate component
    local -a components=()

    IFS='/' read -r -a components <<< "$relative"
    candidate="$root"
    for component in "${components[@]}"; do
        candidate="$candidate/$component"
        [[ ! -L "$candidate" ]] || return 1
    done
}
