# `lib_git.sh`

Git helpers for Bash commands that need lightweight repository inspection or update behavior.

## Dependency

Source `lib/bash/std/lib_std.sh` before this library so logging and shared error handling are available.

## Public API

- `git_update_repo`
  Update a repository on its detected default branch, optionally allowing tracked changes in one specific path.
- `git_get_current_branch`
  Return the current branch name through a caller-provided variable, or `detached head`.
- `check_script_up_to_date`
  Check whether a tracked script appears current relative to its configured upstream.

## Internal Helper

- `_git_only_path_dirty`
  Internal predicate used by `git_update_repo` when an allowed dirty path is provided.

## Usage

```bash
source "/absolute/path/to/lib/bash/std/lib_std.sh"
source "/absolute/path/to/lib/bash/git/lib_git.sh"

branch=""
git_get_current_branch "$PWD" branch
log_info "Current branch: $branch"
```

## Behavior Notes

- `git_update_repo` only attempts updates when the checked-out branch is the detected default branch, or an explicit expected branch passed by the caller.
- `git_update_repo` retries `git pull --ff-only` twice by default. Set
  `BASE_GIT_PULL_MAX_ATTEMPTS` to a positive integer to change the retry count.
- `git_get_current_branch` uses `git -C` so it does not change the caller's
  working directory or directory stack. Missing directories and non-Git
  directories return success with an empty result variable.
- `git_update_repo` changes into the target repository while it runs because
  its submodule update sequence depends on repository-relative execution.
- `git_update_repo` only treats an allowed dirty path as safe when every tracked
  change stays within that path. Rename records must have both source and
  destination inside the allowed path.
- `check_script_up_to_date` treats missing git state, untracked scripts, or missing upstreams as skip conditions rather than hard failures.
- `check_script_up_to_date <script>` compares `HEAD` with the local remote-tracking upstream ref. It does not fetch by default, so the result reflects the freshness of local refs.
- `check_script_up_to_date --fetch <script>` runs `git fetch --quiet` first, then compares against the refreshed upstream ref. If fetch fails, the helper logs a warning and falls back to local remote-tracking refs.
- `check_script_up_to_date` returns `2` when the repository is behind upstream,
  and `3` when the script has local modifications. If both are true, local
  modifications take precedence and the helper returns `3` after logging both
  conditions.

## Tests

BATS coverage lives in `tests/lib_git.bats`.
