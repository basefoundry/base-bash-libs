# shellcheck shell=bash
# Optional consumer helper for Bats projects. It deliberately has no Bats
# dependency so projects can load it from their own test_helper.bash.

base_bats_repo_root() {
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P
}

base_bats_framework_dir() {
    printf '%s\n' "${BASE_BASH_LIBS_DIR:-$(base_bats_repo_root)/lib/bash}"
}

base_bats_run() {
    local project_root="$1"
    shift

    BASE_BASH_LIBS_DIR="$(base_bats_framework_dir)" \
        "$project_root/bin/app" "$@"
}

base_bats_check() {
    local project_root="$1"
    local format="${2:-human}"
    local launcher
    launcher="$(base_bats_repo_root)/bin/base-bash"

    BASE_BASH_LIBS_DIR="$(base_bats_framework_dir)" \
        "$launcher" check --project "$project_root" --format "$format"
}
