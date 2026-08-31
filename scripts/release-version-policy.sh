# shellcheck shell=bash

# One repository-owned SemVer policy for the supported v2 release line.
# Stable releases use 2.MINOR.PATCH. Approved prereleases append
# -(alpha|beta|rc).N, where every numeric component is canonical decimal.
base_bash_release_version_kind() {
    local version="${1-}"
    local numeric='(0|[1-9][0-9]*)'
    local stable_re="^2[.]${numeric}[.]${numeric}$"
    local prerelease_re="^2[.]${numeric}[.]${numeric}-(alpha|beta|rc)[.]([1-9][0-9]*)$"

    if [[ "$version" =~ $stable_re ]]; then
        printf 'stable\n'
        return 0
    fi
    if [[ "$version" =~ $prerelease_re ]]; then
        printf 'prerelease\n'
        return 0
    fi
    return 1
}

base_bash_release_version_supported() {
    base_bash_release_version_kind "${1-}" > /dev/null
}
