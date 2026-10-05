#!/usr/bin/env bash

# Validate the empty Unreleased placeholder against the repository's release
# state. An untagged dated section matching VERSION is the expected shape of a
# release-preparation branch and is allowed to keep the placeholder.
check_changelog_unreleased_placeholder() {
    local repo_root="$1"
    local version="$2"
    local changelog_path="$repo_root/CHANGELOG.md"
    local latest_release_ref
    local unreleased_commit_count

    if [[ "$(grep -c '^## \[Unreleased\]' "$changelog_path")" != 1 ]]; then
        printf 'CHANGELOG.md must contain exactly one [Unreleased] section.\n' >&2
        return 1
    fi
    if ! grep -F 'No unreleased changes yet.' "$changelog_path" > /dev/null; then
        return 0
    fi

    latest_release_ref="$(git -C "$repo_root" describe --tags --match 'v[0-9]*' --abbrev=0 2> /dev/null || true)"
    [[ -z "$latest_release_ref" ]] && return 0

    if grep -F "## [$version]" "$changelog_path" > /dev/null &&
        ! git -C "$repo_root" rev-parse --verify --quiet "refs/tags/v$version" > /dev/null; then
        return 0
    fi

    unreleased_commit_count="$(git -C "$repo_root" rev-list --count "$latest_release_ref..HEAD" 2> /dev/null || printf '0')"
    if [[ "$unreleased_commit_count" =~ ^[1-9][0-9]*$ ]]; then
        printf 'CHANGELOG.md cannot retain the empty Unreleased placeholder while %s has %s commits after %s.\n' \
            "$latest_release_ref" "$unreleased_commit_count" "$latest_release_ref" >&2
        return 1
    fi
    return 0
}
