#!/usr/bin/env bash

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)" || exit 1
export BASE_BASH_LIBS_DIR="$repo_root/lib/bash"

# shellcheck source=/dev/null
source "$BASE_BASH_LIBS_DIR/std/lib_std.sh"
base_std_import cli/lib_cli.sh
# shellcheck source=base_bashly.sh
source "$repo_root/integrations/bashly/base_bashly.sh"

declare -a app_args=()
base_bashly_init app_args

bashly_release() {
    printf 'release=%s\n' "${1-unknown}"
}

base_cli_model_init release name=release version=2.0.0 description="Bashly adapter example"
base_cli_command release publish "Publish a release" handler=bashly_release
base_cli_positional release publish version required=true

base_bashly_run release -- publish "${app_args[@]-candidate}"
