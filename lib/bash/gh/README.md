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

## Boundary

This library is intentionally generic. It does not know about Base branch
names, issue categories, GitHub Project fields, repository baselines, generated
pull request bodies, or any other Base workflow policy.
