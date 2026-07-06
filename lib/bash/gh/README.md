# GitHub CLI Helpers

`lib_gh.sh` provides thin wrappers around the GitHub CLI for scripts that want
consistent command checks and authentication diagnostics without adopting Base's
GitHub workflow policy.

Source the stdlib before this library:

```bash
source "/path/to/base-bash-libs/lib/bash/std/lib_std.sh"
import "/path/to/base-bash-libs/lib/bash/gh/lib_gh.sh"
```

## Public Functions

- `gh_require_cli [install_hint]`
  Verifies that `gh` is available on `PATH`. When it is missing, the helper logs
  a generic error and an optional caller-provided install hint.
- `gh_auth_status_diagnostics [login_hint]`
  Runs `gh auth status -h github.com`. On failure, it logs non-empty diagnostic
  lines from the GitHub CLI and then logs a caller-provided login hint, or the
  default `gh auth login -h github.com` hint.
- `gh_report_command_failure <status> [gh args...]`
  Logs a failed `gh` command and appends auth diagnostics. The original status
  is returned.
- `gh_run [gh args...]`
  Runs `gh "$@"` after command availability checks. On command failure, it
  reports the failed command and auth diagnostics while preserving the original
  exit status.
- `gh_repo_from_remote_url <remote_url> <result_var>`
  Parses supported GitHub SSH and HTTPS remote URLs into `owner/repo`. Returns
  non-zero for non-GitHub or malformed remotes and leaves the result variable
  unchanged on failure.
- `gh_infer_repo_from_origin <repo_dir> <result_var> [--optional]`
  Reads the `origin` remote from a local Git repository and stores `owner/repo`
  when it points to GitHub. With `--optional`, missing or non-GitHub remotes
  store an empty string and return success.
- `gh_detect_default_branch <repo_dir> <result_var>`
  Detects a local repository's default branch from `origin/HEAD`, then
  `origin/main`, local `main`, `origin/master`, and local `master`. Returns
  non-zero when no default branch can be detected.
- `gh_repo_default_branch <owner/repo> <result_var>`
  Uses `gh repo view` to read the GitHub repository default branch.
- `gh_api_with_retry [gh api args...]`
  Runs `gh api "$@"` with bounded retries for API pressure and transient server
  errors such as secondary rate limits, `Retry-After`, abuse detection, and
  502/503/504-style failures. `BASE_GH_API_MAX_ATTEMPTS` defaults to `2`.
  `BASE_GH_API_RETRY_DELAY_SECONDS` defaults to `2` when the error output does
  not include a `Retry-After` value.
- `gh_worktree_path_for_branch <branch> [repo_dir]`
  Prints the path of the Git worktree attached to a local branch. Returns
  non-zero when no worktree is attached.
- `gh_list_worktree_branches [repo_dir]`
  Prints tab-separated `path<TAB>branch` rows from `git worktree list
  --porcelain`.
- `gh_branch_upstream <repo_dir> <branch>`
  Prints the configured upstream ref for a local branch.
- `gh_branch_merged_to_ref <repo_dir> <branch> <ref>`
  Returns success when `refs/heads/<branch>` is an ancestor of `<ref>`.
- `gh_list_remote_branches [repo_dir]`
  Prints branch names from `git ls-remote --heads origin`.

## Boundary

This library is intentionally generic. It does not know about Base branch
names, issue categories, GitHub Project fields, repository baselines, generated
pull request bodies, or any other Base workflow policy.
