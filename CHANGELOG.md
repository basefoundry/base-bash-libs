# Changelog

All notable changes to base-bash-libs will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions are tracked in the repo-root `VERSION` file.

## [Unreleased]

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
