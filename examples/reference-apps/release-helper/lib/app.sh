# shellcheck shell=bash
# Reference CI/release utility. Network mutation is explicit and opt-in.

base_launcher_import_base_bash_lib cli/lib_cli.sh app/lib_app.sh git/lib_git.sh gh/lib_gh.sh

base_cli_model_init release_helper name=base-release-helper version=2.0.0 description="Auditable release utility" handler=release_helper_dispatch
base_cli_command release_helper check "Inspect repository and artifact readiness" handler=release_helper_dispatch
base_cli_command release_helper plan "Print a non-mutating release plan" handler=release_helper_dispatch
base_cli_command release_helper publish "Publish through the checked GitHub boundary" handler=release_helper_dispatch
base_cli_command release_helper rollback "Describe the immutable rollback target" handler=release_helper_dispatch
base_app_init release_helper_policy name=base-release-helper
base_app_config_define release_helper_policy repository string default="basefoundry/base-bash-libs" env=BASE_REFERENCE_REPOSITORY
base_app_config_define release_helper_policy artifact path default="" env=BASE_REFERENCE_ARTIFACT
base_app_config_define release_helper_policy token string default="" env=GH_TOKEN secret=true
base_app_add_standard_options release_helper ""

release_helper_execute() {
    local command="${BASE_BASH_LIBS_CLI_RESULT_COMMAND:-}" repository artifact token branch
    base_app_apply_standard_options release_helper_policy
    base_app_config_load release_helper_policy || return $?
    base_app_config_get release_helper_policy repository repository || return $?
    base_app_config_get release_helper_policy artifact artifact || return $?
    base_app_config_get release_helper_policy token token || return $?

    case "$command" in
        check|plan)
            branch="unknown"
            base_git_get_current_branch "$PWD" branch 2>/dev/null || true
            printf 'repository=%s\n' "$repository"
            printf 'branch=%s\n' "$branch"
            printf 'artifact=%s\n' "${artifact:-not-selected}"
            printf 'mutation=disabled\n'
            ;;
        publish)
            [[ -n "$artifact" ]] || {
                base_std_log_error -l reference.release "artifact is required for publish"
                return 2
            }
            if ((BASE_BASH_LIBS_APP_DRY_RUN)); then
                printf 'dry-run=publish:%s\n' "$repository" >&2
                return 0
            fi
            base_gh_run --sensitive --safe-display "$repository" release view "$artifact" >/dev/null
            ;;
        rollback)
            printf 'rollback=select-the-previous-immutable-release\n'
            printf 'repository=%s\n' "$repository"
            ;;
        *)
            base_std_log_error -l reference.release "unknown command '$command'"
            return 2
            ;;
    esac
}

release_helper_dispatch() { base_app_run release_helper_policy release_helper_execute; }
main() { base_cli_run release_helper -- "$@"; }
