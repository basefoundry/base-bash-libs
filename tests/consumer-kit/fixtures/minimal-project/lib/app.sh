# shellcheck shell=bash
base_launcher_import_base_bash_lib cli/lib_cli.sh
base_cli_model_init fixture name=fixture version=2.0.0 handler=fixture_main
fixture_main() { printf 'fixture=ok\n'; }
main() { base_cli_run fixture -- "$@"; }
