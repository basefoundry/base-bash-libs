# Changelog

All notable changes to base-bash-libs will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions are tracked in the repo-root `VERSION` file.

## [Unreleased]

### Fixed

- Hardened `arg_parse` option specifications against duplicate, empty, and
  unreachable tokens, and added repeatable value options with ordered,
  caller-owned indexed-array outputs.
- Hardened file-section marker validation, preserved symlink targets during
  atomic updates, and treated option-like target paths literally.

- Made fallback timeouts terminate descendant processes when a command is
  launched in its own process group.
- Isolated pre-existing EXIT trap control flow so return or exit cannot skip
  registered cleanup hooks and paths.
- Normalized decimal integer inputs before arithmetic validation and rejected
  inverted argument or range bounds.
- Stopped wrapper-option filtering at the -- argument terminator and kept
  launcher runtime-filter state local to each script invocation.
- Preserved caller OPTIND, maintained batch prepend order in add_to_path, and
  treated option-like paths literally in safe_touch.

- Hardened named-output helpers across std, string, list, arg, git, and GitHub
  libraries against caller variable names that collide with helper internals.
- Rejected readonly caller-owned output variables before helper side effects.
- Aligned standards and stdlib documentation with the current sourceable
  library surface and standalone checkout path.
- Added public associative-array assertions and moved `arg_parse` caller-owned
  map validation onto the public assertion API.
- Added cleanup path unregister support and used it for eager temp cleanup.
- Made `gh_run` report failed GitHub CLI commands even when callers enable
  `set -e`, and preserved argument boundaries in GitHub command failure logs.
- Documented and tested `str_split` trailing-separator behavior.
- Hardened GitHub helper pass-by-name outputs against internal variable
  shadowing, added a non-optional `gh_infer_repo_from_origin` error message,
  and deduplicated worktree parsing loops.
- Kept `gh_list_remote_branches` from leaking its internal SHA loop variable
  into caller scope.
- Routed `gh_api_with_retry` retry sleeps through the stdlib sleep helper so
  shell `sleep` aliases or functions cannot shadow retry delays.
- Made `arg_parse` publish output arrays only after a parse succeeds, leaving
  caller-owned outputs unchanged on late parse failures.
- Kept the warning-level ShellCheck profile clean for file section marker-count
  validation.
- Reused shared marker validation inside `update_file_section`.

## [1.2.0] - 2026-07-04

### Added

- Added `lib/bash/gh/lib_gh.sh` with generic GitHub CLI availability,
  authentication diagnostics, failure reporting, and checked command execution
  helpers.

### Fixed

- Hardened `std_run --timeout` retry internals so timeout discovery is cached
  per call, fallback setup failures return a generic error, and fallback timer
  cleanup cannot remove the timeout marker before it is observed.
- Clarified `update_file_section` logging when appending a new managed section.

### Removed

- Removed early compatibility aliases `run`, `std_run_with_timeout`, and
  `str_in_array`; use `std_run`, `std_run --timeout`, and `list_contains`
  instead.

## [1.1.0] - 2026-07-03

### Added

- Added the `base-bash` launcher for standalone scripts that want the
  base-bash-libs stdlib preloaded from a shebang.
- Added `std_run --timeout`, `--max-attempts`, and `--retry-delay` execution
  policy options for timeout-only, retry-only, and timeout-plus-retry command
  execution.

### Changed

- Changed string case and trim helpers to mutate named variables in place
  instead of requiring command substitution.
- Added public `assert_variable_name` validation for helpers that accept Bash
  variable names.
- Deprecated `std_run_with_timeout` in documentation for new code; it remains as
  a compatibility wrapper around `std_run --timeout`.
- Changed cleanup path registration to require absolute paths so exit cleanup
  cannot drift after a script changes directory.
- Changed the Bash timeout fallback to kill TERM-ignoring commands after a short
  grace period.
- Changed list and string array helpers to require caller-declared indexed arrays
  instead of silently coercing scalar variables.
- Changed repository validation to run a warning-level ShellCheck profile for
  production libraries, examples, validation scripts, and shared test helpers.

## [1.0.0] - 2026-06-21

### Added

- Added `lib/bash/str/lib_str.sh` with string case, trim, predicate, split,
  join, and membership helpers.
- Added a documented stdlib-loaded marker for companion-library dependency
  guards.
- Added stdlib cleanup hook and cleanup path registration backed by a shared
  `EXIT` trap.
- Added portable stdlib temporary file and directory helpers with default exit
  cleanup.
- Added stdlib command path and function introspection helpers.
- Added `std_run_with_timeout` for bounded command execution with macOS/Linux
  fallback behavior.

### Fixed

- Made the Tests workflow run on `main` pushes after the default-branch
  migration.

## [0.2.1] - 2026-06-18

### Changed

- Changed the project license from AGPL-3.0-or-later to Apache-2.0 for broader
  generic library adoption.
- Refreshed the top-level README entry point with release metadata, direct
  links to each library README, and clearer Homebrew companion-library imports.
- Added `NOTICE` so Apache-2.0 attribution is carried in a dedicated file.
- Added validation that keeps the README version strip aligned with the
  repo-root `VERSION` file.

## [0.2.0] - 2026-06-18

### Added

- Added `std_run` as the preferred command-runner API while retaining `run` as
  a compatibility wrapper.
- Added readonly `BASE_BASH_LIBS_VERSION`, sourced from the package `VERSION`
  file when `lib_std.sh` loads.
- Added optional `--fetch` support to `check_script_up_to_date` for callers
  that want a live upstream freshness check.
- Added Linux and supported-Bash GitHub Actions validation coverage.
- Added PTY-backed coverage for `wait_for_enter`.
- Added non-Homebrew installation documentation for source checkouts, vendored
  copies, and git submodule layouts.

### Changed

- Documented Homebrew tap trust and standalone Homebrew install usage.
- Preserved target file modes when `update_file_section` appends or replaces
  managed sections.
- Hardened `update_file_section` marker ordering, empty-file behavior, and
  missing-file no-op semantics.
- Validated variable-name arguments consistently across stdlib and git helpers.
- Respected `NO_COLOR` during explicit color initialization and composed
  structured log records before one final stderr write.
- Aligned file-log warning source locations with the shared logging caller
  lookup.
- Made `safe_mkdir` option parsing and empty-argument behavior explicit.
- Made `git_get_current_branch` use `git -C` so it does not perturb the caller's
  directory stack.
- Added configurable `BASE_GIT_PULL_MAX_ATTEMPTS` support for git pull retries.

### Fixed

- Failed cleanly when `lib_std.sh` is sourced by unsupported Bash versions.
- Returned nonzero from `set_log_level` for invalid input without changing
  existing logger levels.
- Added explicit dependency guards for companion libraries sourced without the
  stdlib.
- Clarified and tested `git_get_current_branch` behavior for missing and
  non-Git directories.

## [0.1.0] - 2026-06-17

### Added

- Initialized the repository with the Base-managed repo baseline.
- Added the standalone Bash `std`, `file`, and `git` libraries copied from
  Base, including BATS coverage, ShellCheck validation, and a standalone usage
  example.
