# Base Bash v2 symbol map

Base Bash v2 has one short public function namespace: `bl_`. Public metadata,
configuration, and runtime state remain under `BASE_BASH_LIBS_`. Implementation-
only functions use `__base_bash_libs_...__` and
are intentionally outside the compatibility contract.

The v2 release is a clean break. Generic v1 names are not defined and no
compatibility alias is installed. For source trees or scripts that still use
the v1 surface, run `scripts/migrate-v2-symbols` on a copy or a clean branch,
then review the result and run the consumer's tests.

## Public function map

The tables below are complete by module. Where a rule is shown, every legacy
name in that row is covered by the rule; the explicit lists make the inventory
auditable without requiring a parser.

### Standard library

`bl_init` and `bl_require_version` already use the v2
package namespace and keep their names. Every other listed stdlib function
maps to `bl_std_` followed by the legacy name with a leading
`std_` removed when present.

| Legacy names | v2 names |
| --- | --- |
| `is_interactive`, `check_bash_version`, `import`, `add_to_path`, `dedupe_path`, `print_path` | `bl_std_is_interactive`, `bl_std_check_bash_version`, `bl_std_import`, `bl_std_add_to_path`, `bl_std_dedupe_path`, `bl_std_print_path` |
| `set_log_level`, `set_log_category_level`, `log_is_enabled` | `bl_std_set_log_level`, `bl_std_set_log_category_level`, `bl_std_log_is_enabled` |
| `log_fatal`, `log_error`, `log_warn`, `log_info`, `log_debug`, `log_verbose` | `bl_std_log_fatal`, `bl_std_log_error`, `bl_std_log_warn`, `bl_std_log_info`, `bl_std_log_debug`, `bl_std_log_verbose` |
| `log_info_file`, `log_debug_file`, `log_verbose_file` | `bl_std_log_info_file`, `bl_std_log_debug_file`, `bl_std_log_verbose_file` |
| `log_info_enter`, `log_debug_enter`, `log_verbose_enter`, `log_info_leave`, `log_debug_leave`, `log_verbose_leave` | `bl_std_log_info_enter`, `bl_std_log_debug_enter`, `bl_std_log_verbose_enter`, `bl_std_log_info_leave`, `bl_std_log_debug_leave`, `bl_std_log_verbose_leave` |
| `print_error`, `print_warn`, `print_info`, `print_success`, `print_bold`, `print_message`, `print_tty`, `dump_trace` | `bl_std_print_error`, `bl_std_print_warn`, `bl_std_print_info`, `bl_std_print_success`, `bl_std_print_bold`, `bl_std_print_message`, `bl_std_print_tty`, `bl_std_dump_trace` |
| `exit_if_error`, `fatal_error`, `is_dry_run`, `std_run` | `bl_std_exit_if_error`, `bl_std_fatal_error`, `bl_std_is_dry_run`, `bl_std_run` |
| `safe_mkdir`, `safe_touch`, `safe_truncate`, `safe_cd`, `safe_unalias` | `bl_std_safe_mkdir`, `bl_std_safe_touch`, `bl_std_safe_truncate`, `bl_std_safe_cd`, `bl_std_safe_unalias` |
| `std_register_cleanup_hook`, `std_unregister_cleanup_hook`, `std_register_cleanup_path`, `std_unregister_cleanup_path` | `bl_std_register_cleanup_hook`, `bl_std_unregister_cleanup_hook`, `bl_std_register_cleanup_path`, `bl_std_unregister_cleanup_path` |
| `std_make_temp_file`, `std_make_temp_dir`, `std_command_path`, `std_function_exists` | `bl_std_make_temp_file`, `bl_std_make_temp_dir`, `bl_std_command_path`, `bl_std_function_exists` |
| `assert_variable_name`, `assert_indexed_array`, `assert_associative_array`, `assert_function_exists`, `assert_not_null` | `bl_std_assert_variable_name`, `bl_std_assert_indexed_array`, `bl_std_assert_associative_array`, `bl_std_assert_function_exists`, `bl_std_assert_not_null` |
| `assert_integer`, `assert_integer_range`, `assert_arg_count`, `assert_command_exists`, `assert_file_exists`, `assert_executable`, `assert_dir_exists` | `bl_std_assert_integer`, `bl_std_assert_integer_range`, `bl_std_assert_arg_count`, `bl_std_assert_command_exists`, `bl_std_assert_file_exists`, `bl_std_assert_executable`, `bl_std_assert_dir_exists` |
| `get_my_source_dir`, `ask_yes_no`, `wait_for_enter` | `bl_std_get_my_source_dir`, `bl_std_ask_yes_no`, `bl_std_wait_for_enter` |

### Companion libraries

| Module | Legacy names | v2 names |
| --- | --- | --- |
| file | `file_section_exists`, `file_section_needs_update`, `update_file_section` | `bl_file_section_exists`, `bl_file_section_needs_update`, `bl_file_update_file_section` |
| git | `git_detect_default_branch`, `git_worktree_path_for_branch`, `git_list_worktree_branches`, `git_branch_upstream`, `git_branch_merged_to_ref`, `git_list_remote_branches`, `git_update_repo`, `git_get_current_branch`, `check_script_up_to_date` | `bl_git_detect_default_branch`, `bl_git_worktree_path_for_branch`, `bl_git_list_worktree_branches`, `bl_git_branch_upstream`, `bl_git_branch_merged_to_ref`, `bl_git_list_remote_branches`, `bl_git_update_repo`, `bl_git_get_current_branch`, `bl_git_check_script_up_to_date` |
| gh | `gh_require_cli`, `gh_auth_status_diagnostics`, `gh_report_command_failure`, `gh_run`, `gh_repo_from_remote_url`, `gh_infer_repo_from_origin`, `gh_repo_default_branch`, `gh_api_with_retry` | `bl_gh_require_cli`, `bl_gh_auth_status_diagnostics`, `bl_gh_report_command_failure`, `bl_gh_run`, `bl_gh_repo_from_remote_url`, `bl_gh_infer_repo_from_origin`, `bl_gh_repo_default_branch`, `bl_gh_api_with_retry` |
| str | `str_lower`, `str_upper`, `str_ltrim`, `str_rtrim`, `str_trim`, `str_contains`, `str_starts_with`, `str_ends_with`, `str_split`, `str_join` | `bl_str_lower`, `bl_str_upper`, `bl_str_ltrim`, `bl_str_rtrim`, `bl_str_trim`, `bl_str_contains`, `bl_str_starts_with`, `bl_str_ends_with`, `bl_str_split`, `bl_str_join` |
| arg | `arg_parse` | `bl_arg_parse` |
| list | `list_append`, `list_prepend`, `list_remove`, `list_contains`, `list_unique`, `list_length` | `bl_list_append`, `bl_list_prepend`, `bl_list_remove`, `bl_list_contains`, `bl_list_unique`, `bl_list_length` |

The standalone launcher keeps `main` as the application entrypoint. Its helper
functions use `bl_launcher_`:

| Legacy name | v2 name |
| --- | --- |
| `base_bash_die`, `base_bash_resolve_path`, `base_bash_package_root`, `base_bash_ensure_supported_bash` | `bl_launcher_die`, `bl_launcher_resolve_path`, `bl_launcher_package_root`, `bl_launcher_ensure_supported_bash` |
| `base_bash_lib_dir_is_usable`, `base_bash_resolve_lib_dir`, `base_bash_source_stdlib` | `bl_launcher_lib_dir_is_usable`, `bl_launcher_resolve_lib_dir`, `bl_launcher_source_stdlib` |
| `import_base_bash_lib`, `base_bash_run_script`, `base_bash_usage` | `bl_launcher_import_base_bash_lib`, `bl_launcher_run_script`, `bl_launcher_usage` |

The application-defined `main` function is intentionally not namespaced.

## Global and environment map

| Legacy name | v2 name |
| --- | --- |
| `__SCRIPT_ARGS__` | `BASE_BASH_LIBS_SCRIPT_ARGS` |
| `__SCRIPT_DIR__` | `BASE_BASH_LIBS_SCRIPT_DIR` |
| `__color__` | `BASE_BASH_LIBS_STD_COLOR_ENABLED` |
| `COLOR_BOLD`, `COLOR_RED`, `COLOR_GREEN`, `COLOR_YELLOW`, `COLOR_BLUE`, `COLOR_OFF` | `BASE_BASH_LIBS_STD_COLOR_BOLD`, `BASE_BASH_LIBS_STD_COLOR_RED`, `BASE_BASH_LIBS_STD_COLOR_GREEN`, `BASE_BASH_LIBS_STD_COLOR_YELLOW`, `BASE_BASH_LIBS_STD_COLOR_BLUE`, `BASE_BASH_LIBS_STD_COLOR_OFF` |
| `LOG_DEBUG`, `LOG_UTC` | `BASE_BASH_LIBS_LOG_DEBUG`, `BASE_BASH_LIBS_LOG_UTC` |
| `BASE_BASH_BOOTSTRAP_SOURCE` | `BASE_BASH_LIBS_BOOTSTRAP_SOURCE` |
| `BASE_CLI_PRIMARY_LOG` | `BASE_BASH_LIBS_PRIMARY_LOG` |
| `BASE_GIT_PULL_MAX_ATTEMPTS` | `BASE_BASH_LIBS_GIT_PULL_MAX_ATTEMPTS` |
| `BASE_BASH_FILE_START_MARKER`, `BASE_BASH_FILE_END_MARKER`, `BASE_BASH_FILE_NEW_CONTENT_FILE` | `BASE_BASH_LIBS_FILE_START_MARKER`, `BASE_BASH_LIBS_FILE_END_MARKER`, `BASE_BASH_LIBS_FILE_NEW_CONTENT_FILE` |
| `DRY_RUN`, `dry_run` | `BASE_BASH_LIBS_DRY_RUN` |
| `__lib_std_sourced__`, `__lib_file_sourced__`, `__lib_git_sourced__`, `__lib_gh_sourced__`, `__lib_str_sourced__`, `__lib_arg_sourced__`, `__lib_list_sourced__` | `BASE_BASH_LIBS_STDLIB_LOADED`, `BASE_BASH_LIBS_FILE_LOADED`, `BASE_BASH_LIBS_GIT_LOADED`, `BASE_BASH_LIBS_GH_LOADED`, `BASE_BASH_LIBS_STR_LOADED`, `BASE_BASH_LIBS_ARG_LOADED`, `BASE_BASH_LIBS_LIST_LOADED` |
| `_log_levels`, `_loggers_level_map`, `_log_category_level_map`, `_log_primary_sink_failed_paths` | `BASE_BASH_LIBS_STD_LOG_LEVELS`, `BASE_BASH_LIBS_STD_LOGGER_LEVELS`, `BASE_BASH_LIBS_STD_LOG_CATEGORY_LEVELS`, `BASE_BASH_LIBS_STD_LOG_FAILED_SINKS` |

`NO_COLOR`, `PATH`, `TMPDIR`, `BASH_*`, `GH_*`, `TZ`, and other documented
shell or ecosystem variables remain caller-owned inputs. The framework does
not define or export them, so they are not part of its symbol namespace.

## Internal prefix map

All implementation-only functions and local holders use the same module
segment under the reserved internal namespace:

| Legacy prefix | v2 prefix |
| --- | --- |
| `__lib_std_require_supported_bash__`, `__std_`, `__log_`, `__print_`, `__init_colors__`, `__join_message__`, `__resolve_log_category_level__`, `__is_valid_variable_name__` | `__base_bash_libs_std_...__` |
| `__file_`, `__preserve_file_mode__` | `__base_bash_libs_file_...__` |
| `__git_` | `__base_bash_libs_git_...__` |
| `__gh_` | `__base_bash_libs_gh_...__` |
| `__arg_` | `__base_bash_libs_arg_...__` |
| `__list_` | `__base_bash_libs_list_...__` |
| `__str_` | `__base_bash_libs_str_...__` |

No v2 compatibility guarantee is made for internal names. New code must not
call them; collision fixtures and static checks ensure generic internal names
are not exported by the libraries.
