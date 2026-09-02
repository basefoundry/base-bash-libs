# shellcheck shell=bash
base_launcher_import_base_bash_lib cli/lib_cli.sh
__base_bash_generated_app_version=""
# shellcheck disable=SC2154 # bin/app publishes the generated project root.
__base_bash_generated_app_version="$(sed -n '1p' "$app_project_root/VERSION" || true)"
if [[ -z "$__base_bash_generated_app_version" ]]; then
    printf 'ERROR: unable to read the application version from %s\n' "$app_project_root/VERSION" >&2
    return 1
fi
base_cli_model_init fixture name=fixture version="$__base_bash_generated_app_version" handler=fixture_main
unset __base_bash_generated_app_version
fixture_main() { printf 'fixture=ok\n'; }
main() { base_cli_run fixture -- "$@"; }
