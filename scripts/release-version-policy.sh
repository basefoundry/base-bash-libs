# shellcheck shell=bash

# This file owns the repository's canonical SemVer grammar. The sourceable
# stdlib and standalone launcher mirror the expression because those artifact
# boundaries cannot import this script; tests/validate.sh rejects drift.
base_bash_semver_kind() {
    local version="${1-}"
    local canonical_semver_re='^(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)(-(alpha|beta|rc)[.]([1-9][0-9]*))?$'

    [[ "$version" =~ $canonical_semver_re ]] || return 1
    if [[ "$version" == *-* ]]; then
        printf 'prerelease\n'
    else
        printf 'stable\n'
    fi
}

base_bash_semver_supported() {
    base_bash_semver_kind "${1-}" > /dev/null
}

# Stable releases use 2.MINOR.PATCH. Approved prereleases append
# -(alpha|beta|rc).N, where every numeric component is canonical decimal.
base_bash_release_version_kind() {
    local version="${1-}"

    base_bash_semver_supported "$version" || return 1
    [[ "$version" == 2.* ]] || return 1
    base_bash_semver_kind "$version"
}

base_bash_release_version_supported() {
    base_bash_release_version_kind "${1-}" > /dev/null
}
