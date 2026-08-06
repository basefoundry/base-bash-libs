# shellcheck shell=bash
# Reference installer/updater application. Keep this application policy in one
# physical file; it is deliberately generated-free so consumers can inspect it.

base_launcher_import_base_bash_lib cli/lib_cli.sh app/lib_app.sh file/lib_file.sh

base_cli_model_init installer name=base-installer version=2.0.0 description="Verified installer and updater" handler=installer_dispatch
base_cli_command installer install "Install a verified artifact" handler=installer_dispatch
base_cli_command installer update "Update an existing installation" handler=installer_dispatch
base_cli_command installer rollback "Restore the previous installation" handler=installer_dispatch
base_cli_command installer status "Inspect installation state" handler=installer_dispatch
base_app_init installer_policy name=base-installer
base_app_config_define installer_policy target path default="/tmp/base-reference-install" env=BASE_REFERENCE_INSTALL_TARGET
base_app_config_define installer_policy artifact path default="" env=BASE_REFERENCE_ARTIFACT
base_app_config_define installer_policy token string default="" env=BASE_REFERENCE_TOKEN secret=true
base_app_add_standard_options installer ""

installer_cleanup() {
    base_std_log_debug -l reference.installer "cleanup phase=$1 status=$2"
}

installer_execute() {
    local command="${BASE_BASH_LIBS_CLI_RESULT_COMMAND:-}" target artifact token
    local -a config_args=()

    base_app_apply_standard_options installer_policy
    base_cli_result_get config config_file 2>/dev/null && config_args+=(--project "$config_file")
    base_cli_result_get user-config user_config 2>/dev/null && config_args+=(--user "$user_config")
    base_app_config_load installer_policy "${config_args[@]}" || return $?
    base_app_hook installer_policy cleanup installer_cleanup installer_cleanup || return $?
    base_app_config_get installer_policy target target || return $?
    base_app_config_get installer_policy artifact artifact || return $?
    base_app_config_get installer_policy token token || return $?

    case "$command" in
        status)
            printf 'target=%s\n' "$target"
            [[ -e "$target" ]] && printf 'state=installed\n' || printf 'state=absent\n'
            ;;
        install|update|rollback)
            [[ -n "$artifact" ]] || artifact="base-bash-libs.release"
            if ((BASE_BASH_LIBS_APP_DRY_RUN)); then
                printf 'dry-run=%s:%s\n' "$command" "$target" >&2
                return 0
            fi
            base_std_safe_mkdir "$target" || return $?
            base_std_safe_touch "$target/state.txt" || return $?
            base_file_update_file_section "$target/state.txt" \
                '# BEGIN base-reference-installer' '# END base-reference-installer' \
                "operation=$command" "artifact=$artifact" "token=redacted" || return $?
            printf 'operation=%s\n' "$command"
            printf 'target=%s\n' "$target"
            ;;
        *)
            base_std_log_error -l reference.installer "unknown command '$command'"
            return 2
            ;;
    esac
}

installer_dispatch() { base_app_run installer_policy installer_execute; }
main() { base_cli_run installer -- "$@"; }
