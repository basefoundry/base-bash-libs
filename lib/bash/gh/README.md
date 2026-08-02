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
  Logs a failed `gh` command and appends auth diagnostics. Protected reporting
  uses the control-first sensitive form documented below. The original status
  is returned.
- `gh_run [gh args...]`
  Runs `gh "$@"` after command availability checks. On command failure, it
  reports the failed command and auth diagnostics while preserving the original
  exit status. Protected calls use the sensitive form documented below.
- `gh_repo_from_remote_url <remote_url> <result_var>`
  Parses supported GitHub SSH and HTTPS remote URLs into `owner/repo`. Returns
  non-zero for non-GitHub or malformed remotes and leaves the result variable
  unchanged on failure.
- `gh_infer_repo_from_origin <repo_dir> <result_var> [--optional]`
  Reads the `origin` remote from a local Git repository and stores `owner/repo`
  when it points to GitHub. With `--optional`, missing or non-GitHub remotes
  store an empty string and return success.
- `gh_repo_default_branch <owner/repo> <result_var>`
  Uses `gh repo view` to read the GitHub repository default branch.
- `gh_api_with_retry [gh api args...]`
  Runs `gh api "$@"` with bounded retries for API pressure and transient server
  errors such as secondary rate limits, `Retry-After`, abuse detection, and
  502/503/504-style failures. `BASE_GH_API_MAX_ATTEMPTS` defaults to `2`.
  `BASE_GH_API_RETRY_DELAY_SECONDS` defaults to `2` when the error output does
  not include a `Retry-After` value. Protected calls use the sensitive form
  documented below.

All GitHub helper failures return a nonzero status and preserve the underlying
`gh` status where applicable. The remote parser and origin inference helpers
leave caller-owned result variables unchanged on failure; use `--optional` with
`gh_infer_repo_from_origin` when a missing or non-GitHub origin is expected.

Public functions validate the documented argument count before expanding
required positional parameters. Invalid calls return `1`, including when the
caller has enabled `nounset`; optional flags such as `--optional` are rejected
when misspelled. The variadic `gh_run` and `gh_api_with_retry` helpers continue
to pass GitHub arguments after any protected-diagnostic control prefix through
to `gh` unchanged.

The library does not change the caller's `errexit`, `nounset`, `pipefail`,
`shopt`, `IFS`, `OPTIND`, cwd, umask, traps, or positional parameters. Its
diagnostic parsing uses a command-scoped empty `IFS`, and failed `gh` commands
retain their original status from `1` through `255`.

## Secret-safe command diagnostics

Ordinary `gh_run` and `gh_report_command_failure` failures render every GitHub
argument with Bash `%q`. This preserves argument boundaries and produces a
copyable diagnostic, but it is not secret-safe. Headers, fields, URL userinfo,
positional values, and `--option=value` forms are all rendered as supplied.

Use `--sensitive` whenever any GitHub argument may contain a credential or
other value that must not enter terminal or persistent logs:

```bash
gh_run --sensitive --safe-display "create release" -- \
    release create "$tag" --notes "$private_notes"

gh_api_with_retry --sensitive --safe-display "update project item" -- \
    graphql --header "Authorization: Bearer $token" \
    --raw-field "query=$query"

gh_report_command_failure --sensitive --safe-display "publish release" -- \
    "$status" release create "$tag" --notes "$private_notes"
```

A protected call requires the explicit `--` separator. `--safe-display` is
valid only with `--sensitive`; its value must be a non-empty printable ASCII
label that does not begin with `-` and that the caller has already determined
is safe to log. The label appears as, for example, `create release [sensitive
GitHub operation; arguments hidden]`. Without a label the helpers use only the
generic bracketed description.

Protected diagnostics never render the GitHub argv. This applies to final
failure records, retry notices, persistent logs, and the nested authentication
check performed by `gh_run` and `gh_report_command_failure`. A protected
`gh_api_with_retry` may inspect captured failure text internally to decide
whether and when to retry, but it does not replay that text on failure.
Successful API output remains functional stdout and is returned unchanged.

Sensitivity is explicit rather than heuristic. The helpers do not try to infer
which `--header`, `--field`, `--raw-field`, `--option=value`, URL, extension,
alias, or positional argument contains a secret. They also do not sanitize
output emitted by the executed command, whether that command is a shell
function, builtin, or external subprocess. Caller-enabled shell tracing such
as `set -x`, operating-system process listings, and an unsafe label supplied
through `--safe-display` are also outside this guarantee. Callers remain
responsible for those channels and should prefer non-argv credential
mechanisms whenever the invoked tool supports them.

## Boundary

This library is intentionally generic. It does not know about Base branch
names, issue categories, GitHub Project fields, repository baselines, generated
pull request bodies, or any other Base workflow policy.

## Tests

BATS coverage lives in `lib/bash/gh/tests/lib_gh.bats`.
