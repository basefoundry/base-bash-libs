# shellcheck shell=bash
# Reference multi-command operations CLI: status, sync, and diagnose.

base_launcher_import_base_bash_lib cli/lib_cli.sh app/lib_app.sh git/lib_git.sh file/lib_file.sh

base_cli_model_init ops name=base-ops version=2.0.0 description="Multi-command operations CLI" handler=ops_dispatch
base_cli_command ops status "Show repository status" handler=ops_dispatch
base_cli_command ops sync "Synchronize a checked workspace" handler=ops_dispatch
base_cli_command ops diagnose "Run local diagnostics" handler=ops_dispatch
base_cli_command ops completion "Print shell completion metadata" handler=ops_dispatch
base_app_init ops_policy name=base-ops
base_app_config_define ops_policy workspace path default="$PWD" env=BASE_REFERENCE_WORKSPACE
base_app_config_define ops_policy label string default="production" env=BASE_REFERENCE_LABEL
base_app_add_standard_options ops ""

ops_cleanup() {
    base_std_log_debug -l reference.ops "cleanup phase=$1 status=$2"
}

ops_execute() {
    local command="${BASE_BASH_LIBS_CLI_RESULT_COMMAND:-}" workspace label branch
    base_app_apply_standard_options ops_policy
    base_app_config_load ops_policy || return $?
    base_app_hook ops_policy cleanup ops_cleanup ops_cleanup || return $?
    base_app_config_get ops_policy workspace workspace || return $?
    base_app_config_get ops_policy label label || return $?

    case "$command" in
        status)
            branch="unknown"
            base_git_get_current_branch "$workspace" branch 2>/dev/null || true
            printf 'workspace=%s\nlabel=%s\nbranch=%s\n' "$workspace" "$label" "$branch"
            ;;
        sync)
            if ((BASE_BASH_LIBS_APP_DRY_RUN)); then
                printf 'dry-run=sync:%s\n' "$workspace" >&2
            else
                base_git_update_repo "$workspace" || return $?
                printf 'sync=complete\n'
            fi
            ;;
        diagnose)
            base_std_check_bash_version
            base_std_command_path git_path git && printf 'git=%s\n' "$git_path"
            base_std_command_path shellcheck_path shellcheck 2>/dev/null && printf 'shellcheck=%s\n' "$shellcheck_path" || true
            ;;
        completion)
            base_cli_completion_script ops ops_completion
            ;;
        *)
            base_std_log_error -l reference.ops "unknown command '$command'"
            return 2
            ;;
    esac
}

ops_dispatch() { base_app_run ops_policy ops_execute; }
main() { base_cli_run ops -- "$@"; }
