# base-bash-libs v2 API contract

This document is the normative, human-readable contract for the v2 sourceable
Bash libraries. It is intentionally separate from the machine-readable API
manifest planned for #225. The single-file rule in `STANDARDS.md` remains in
force: every library listed here is implemented by one physical `.sh` file.

## 1. Process and status model

Library functions are callable components, not miniature applications. They
return to their caller and never terminate the caller's shell unless the name
explicitly says that it is fatal or exits:

- `bl_std_exit_if_error` and `bl_std_fatal_error` are the intentional
  fail-fast escape hatches. They log, dump a trace where appropriate, and
  terminate the process.
- `bl_launcher_*` is an executable entrypoint implementation. Its `die`,
  re-exec, and script-run paths may terminate because the launcher owns the
  process boundary.
- `bl_std_assert_*` functions are explicit precondition assertions. They are
  fail-fast by design; callers that need recoverable validation should use a
  predicate or validate inputs before calling an assertion.

All other public library functions return a status. The common status classes
are:

| Status | Meaning |
| --- | --- |
| `0` | Success, or a true predicate. |
| `1` | False predicate or recoverable operational failure. |
| `2` | Usage or contract error (arity, malformed option, invalid output name, or invalid value). |
| `3`–`5` | Module-specific Git freshness outcomes documented by `lib_git.sh`. |
| `6` | Optimistic-concurrency conflict: a file changed after it was read and before an atomic commit. |
| `124` | Command attempt exceeded its requested timeout. |
| `125` | Framework/supervisor failure while enforcing a command timeout. |
| `128+n` | A child or supervisor was interrupted by signal `n`. |

Functions preserve the status of a useful underlying operation where doing so
is meaningful, but callers should rely on the documented class rather than a
platform-specific utility's exact status.

## 2. Output, diagnostics, and named outputs

- Standard output is data: paths, predicates represented as values, Git
  listings, and explicit `print_*` output. A successful mutator is silent
  unless its module documentation says it reports progress.
- Diagnostics, warnings, logs, usage text, traces, and failure explanations
  go to standard error. They never contaminate command-substitution data.
- APIs that return a value use one pass-by-name result as their first argument,
  followed by inputs. Result arrays are caller-declared indexed arrays and
  scalar results are caller-owned variables.
- Before any side effect, an output name is checked for valid Bash identifier
  syntax, the reserved `__` prefix, readonly status, correct array kind, and
  aliases with an input or another output. On failure, outputs remain
  unchanged unless an API explicitly documents partial mutation.
- Named-output APIs are preferred over command substitution for values that
  may contain newlines, whitespace, or leading dashes.

## 3. Effects and repeatability

Each public function documents the following dimensions in its module README:

- **Mutation:** whether caller variables, `PATH`, the working directory,
  traps/cleanup registries, environment variables, or files are changed.
- **Idempotency:** whether repeating the call is a no-op, repeats an operation,
  or is rejected.
- **Dry run:** mutating command wrappers honor `BASE_BASH_LIBS_DRY_RUN`; a
  dry-run plan is emitted as a diagnostic on stderr and does not mutate.
- **Environment and shell state:** libraries do not enable strict mode, change
  `IFS`, consume positional parameters while sourced, or silently alter
  caller traps/options. APIs whose purpose is to change `PATH`, `PWD`, or a
  cleanup registry say so explicitly.
- **Filesystem:** paths are handled literally, temporary files are cleaned
  through the shared cleanup registry, and atomic file replacement is used
  where the operation mutates an existing file.

## 4. Interactive behavior

`bl_std_ask_yes_no MESSAGE [yes|no]` defaults to `no` and displays `[y/N]`;
passing `yes` displays `[Y/n]`. `y`/`n` are accepted case-insensitively, and
Enter accepts the displayed default. Invalid input is reprompted. Missing
`/dev/tty`, EOF, and non-interactive use return `1` without terminating.
`bl_std_wait_for_enter` has the same non-TTY/EOF rule. Neither API reads from
or mutates the caller's ordinary stdin stream.

## 5. File mutation guarantees

`bl_file_update_file_section` is idempotent and uses a temporary file followed
by an atomic replacement. It resolves symlinks to edit the referent while
leaving the symlink in place, preserves the target mode, and cleans temporary
paths on every failure. Before committing, it compares device, inode, size,
modification time, and change time with a fingerprint captured before the
read. A concurrent change returns status `6` and leaves the newer target
untouched. A failed read, copy, permission preservation, or commit returns a
recoverable nonzero status and never reports success.

## 6. Complete public-surface audit

The following is the complete v2 surface. The module README is the detailed
signature/effects reference; this table makes coverage auditable.

| Module | Public functions | Default result/effect contract |
| --- | --- | --- |
| lifecycle | `bl_init`, `bl_require_version` | Return recoverable setup/version statuses; initialize caller-owned state only once. |
| std predicates and setup | `bl_std_is_interactive`, `bl_std_check_bash_version`, `bl_std_import`, `bl_std_add_to_path`, `bl_std_dedupe_path`, `bl_std_print_path`, `bl_std_set_log_level`, `bl_std_set_log_category_level`, `bl_std_log_is_enabled` | Predicates return `0/1`; import and configuration return `0/1/2`; PATH and log settings intentionally mutate their documented state. |
| std logging and display | `bl_std_log_fatal`, `bl_std_log_error`, `bl_std_log_warn`, `bl_std_log_info`, `bl_std_log_debug`, `bl_std_log_verbose`, `bl_std_log_info_file`, `bl_std_log_debug_file`, `bl_std_log_verbose_file`, `bl_std_log_info_enter`, `bl_std_log_debug_enter`, `bl_std_log_verbose_enter`, `bl_std_log_info_leave`, `bl_std_log_debug_leave`, `bl_std_log_verbose_leave`, `bl_std_print_error`, `bl_std_print_warn`, `bl_std_print_info`, `bl_std_print_success`, `bl_std_print_bold`, `bl_std_print_message`, `bl_std_print_tty`, `bl_std_dump_trace` | Diagnostics use stderr; explicit print/data helpers use stdout as documented; logging itself does not terminate. |
| std process/error | `bl_std_exit_if_error`, `bl_std_fatal_error`, `bl_std_is_dry_run`, `bl_std_run` | The two explicitly named fatal helpers terminate; dry-run is a predicate; `run` returns command/timeout/supervisor status and never hides diagnostics. |
| std filesystem/cleanup | `bl_std_safe_mkdir`, `bl_std_safe_touch`, `bl_std_safe_truncate`, `bl_std_register_cleanup_hook`, `bl_std_unregister_cleanup_hook`, `bl_std_register_cleanup_path`, `bl_std_unregister_cleanup_path`, `bl_std_make_temp_file`, `bl_std_make_temp_dir` | Mutators return recoverable failures; cleanup/temp APIs mutate only their documented registry and owned paths. |
| std validation/reflection | `bl_std_assert_variable_name`, `bl_std_assert_indexed_array`, `bl_std_assert_associative_array`, `bl_std_command_path`, `bl_std_function_exists`, `bl_std_assert_function_exists`, `bl_std_assert_not_null`, `bl_std_assert_integer`, `bl_std_assert_integer_range`, `bl_std_assert_arg_count`, `bl_std_assert_command_exists`, `bl_std_assert_file_exists`, `bl_std_assert_executable`, `bl_std_assert_dir_exists` | Predicates return status; explicit `assert_*` APIs are intentional fail-fast precondition checks; named outputs are validated before writes. |
| std miscellaneous | `bl_std_safe_cd`, `bl_std_safe_unalias`, `bl_std_get_my_source_dir`, `bl_std_ask_yes_no`, `bl_std_wait_for_enter` | `safe_cd` changes `PWD`; source-dir writes one validated output; interactive functions return recoverable EOF/non-TTY statuses. |
| file | `bl_file_section_exists`, `bl_file_section_needs_update`, `bl_file_update_file_section` | Read-only predicates do not mutate; update is idempotent, symlink-preserving, atomic, metadata-preserving, and conflict-aware. |
| git | `bl_git_detect_default_branch`, `bl_git_worktree_path_for_branch`, `bl_git_list_worktree_branches`, `bl_git_branch_upstream`, `bl_git_branch_merged_to_ref`, `bl_git_list_remote_branches`, `bl_git_update_repo`, `bl_git_get_current_branch`, `bl_git_check_script_up_to_date` | Read-only inspections use named outputs/stdout as documented; update and freshness helpers return documented recoverable Git statuses. |
| gh | `bl_gh_require_cli`, `bl_gh_auth_status_diagnostics`, `bl_gh_report_command_failure`, `bl_gh_run`, `bl_gh_repo_from_remote_url`, `bl_gh_infer_repo_from_origin`, `bl_gh_repo_default_branch`, `bl_gh_api_with_retry` | Diagnostics go stderr; repository/API values use named outputs; retries are bounded and mutation-aware. |
| str | `bl_str_lower`, `bl_str_upper`, `bl_str_ltrim`, `bl_str_rtrim`, `bl_str_trim`, `bl_str_contains`, `bl_str_starts_with`, `bl_str_ends_with`, `bl_str_split`, `bl_str_join` | String transforms/predicates preserve caller values until validation succeeds; split/join use validated named outputs. |
| arg | `bl_arg_parse` | Parses into caller-owned validated arrays/maps and leaves them unchanged on failure. |
| list | `bl_list_append`, `bl_list_prepend`, `bl_list_remove`, `bl_list_contains`, `bl_list_unique`, `bl_list_length` | Indexed-array mutators/predicates use caller-owned arrays; usage and operational errors return rather than exit. |
| launcher | `bl_launcher_die`, `bl_launcher_resolve_path`, `bl_launcher_package_root`, `bl_launcher_ensure_supported_bash`, `bl_launcher_lib_dir_is_usable`, `bl_launcher_resolve_lib_dir`, `bl_launcher_source_stdlib`, `bl_launcher_import_base_bash_lib`, `bl_launcher_run_script`, `bl_launcher_usage` | Entrypoint helpers may terminate only at the executable process boundary; path and usability helpers return status. `main` remains application-defined. |

## 7. v1.4.0 → v2 migration inventory

This release line is a deliberate clean break. There are no generic aliases and
no inconsistent legacy behavior retained for compatibility.

| Change | Migration consequence |
| --- | --- |
| Public namespace | The pre-release `base_bash_libs_*` names are replaced by the shorter `bl_*` module namespace; globals remain `BASE_BASH_LIBS_*`. |
| Lifecycle | Sourcing is passive; callers invoke `bl_init` explicitly. |
| Error handling | Ordinary imports, version checks, list mutators, safe filesystem helpers, directory changes, and source-dir resolution return statuses instead of terminating. Explicit `fatal`, `exit`, and `assert` names retain their intentional process semantics. |
| Interactive defaults | `bl_std_ask_yes_no` supports `[y/N]` and `[Y/n]`, and Enter accepts the displayed default. |
| File safety | Section updates preserve symlinks/mode and return conflict status `6` when a concurrent writer wins the race. |
| Named outputs | Output-first, caller-declared, prevalidated pass-by-name signatures are mandatory; aliases and readonly/wrong-kind outputs fail before side effects. |

The symbol-level mapping remains in [`v2-symbol-map.md`](v2-symbol-map.md), and
the mechanical checker is [`scripts/migrate-v2-symbols`](../scripts/migrate-v2-symbols).
The next milestone (#225) will derive a machine-readable manifest from this
audit; any manifest disagreement is a release blocker.
