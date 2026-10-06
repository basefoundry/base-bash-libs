# CI and default-branch policy

The `Tests` and `Quality` workflows are release gates, not advisory examples.
They run with `contents: read`, cancel superseded runs, and keep network access
out of the containerized compatibility and lint checks. Actions and container
images are pinned to full immutable commit or digest references; changing one
requires a reviewable dependency update.

Each workflow ends with a stable, fail-closed aggregate context:

- `Product validation` depends on Linux and macOS repository validation, the
  Bash 4.2.53 minimum-runtime smoke, the representative Bash compatibility
  matrix, release/provenance gates, and the pinned Beacon downstream smoke.
- `Quality contract` depends on the ShellCheck, repository-contract, shfmt, and
  actionlint quality lane.

Both aggregates run with `always()` so a cancelled, failed, or unexpectedly
skipped dependency cannot leave a green required context. They explicitly
require every dependency result to equal `success`. The individual lanes remain
visible for diagnosis, while the aggregate contexts are the merge-policy
surface.

These aggregates run in the same `pull_request` workflows they protect; they
are not a trusted `pull_request_target` boundary. That is an intentional
solo-maintainer trade-off for this repository, and changes to the aggregate
logic still require review through the repository's existing workflow.

The workflows emitted by `base-bash init` follow the same policy: every
third-party action is pinned to a full commit SHA and carries a human-readable
release comment. Generated consumer workflows can therefore be reviewed and
upgraded without relying on mutable tags.

The shfmt gate checks every Bash source changed by a pull request (and the
latest commit on `main`). This prevents new formatting debt while allowing the
existing v1-to-v2 codebase to be cleaned incrementally; touching a legacy file
puts its complete contents under the formatter gate.

## Default-branch baseline (current)

`base-bash-libs` follows the same modest default-branch baseline as Base:

- pull requests are required and merges are squash-only;
- the `Base branch naming` ruleset protects non-default branches;
- the `Base default branch protection` ruleset requires the trusted
  `base/issue-branch-policy` status, and prevents deletion and non-fast-forward
  updates;
- administrators remain subject to branch protection; and
- no approval count is a default merge requirement.

## Planned required aggregate contexts

After the aggregate jobs land on `main`, the effective ruleset should require
these exact GitHub Actions contexts in addition to `base/issue-branch-policy`:

| Context | Actions integration | Coverage |
| --- | ---: | --- |
| `Product validation` | `15368` | Supported-platform, minimum-runtime, compatibility, release-contract, and Beacon evidence |
| `Quality contract` | `15368` | ShellCheck, repository quality, shfmt, and actionlint evidence |

The repository owner must add those contexts through the normal reviewed
ruleset/configuration workflow, then read back both the effective ruleset and
classic branch protection. The readback must confirm the exact context names,
integration ID `15368`, strictness, review/thread settings, and any existing
stronger controls. `base/issue-branch-policy` remains required; project metadata
intake remains outside these product gates. Until that administrative readback
is complete, the aggregate checks are present and fail closed but are not yet
merge-blocking.

The repeatable readback commands are:

```bash
gh api repos/basefoundry/base-bash-libs/rulesets
gh api repos/basefoundry/base-bash-libs/branches/main/protection
```

Inspect the returned rules and required-status contexts rather than relying on
the workflow files alone.

This is a merge-policy choice, not a validation waiver. The `Tests` and
`Quality` workflows still run on pull requests and `main`, and their aggregate
contexts are the merge-blocking release gates once the ruleset readback is
complete. Run the complete local validation and release readiness checks
before publishing a release, even when a pull request can merge after the
issue-branch policy succeeds.

The live classic branch-protection rule keeps strict status-check behavior for
any checks configured in the future, but the repository's required merge
contexts are intentionally supplied by the Base-managed ruleset above.

## Emergency procedure

1. Record the incident, affected commit, and reason in the pull request and
   the umbrella issue.
2. Use an administrator-only bypass only for a time-sensitive remediation.
3. Restore branch protection immediately and run the complete workflows on the
   resulting `main` commit.
4. Open a follow-up issue for every skipped policy or validation step, with a
   concrete owner and due date.

## Platform claims

The hosted matrix covers current macOS, Linux/glibc, exact Bash 4.2.53, and
representative Bash 4.x and 5.x releases. Alpine/musl runs in the networkless
release gate. No maintained GitHub-hosted BSD runner is currently available;
BSD remains explicitly advisory until a maintained runner can execute the same
contract. A release must not describe advisory BSD evidence as a supported
guarantee.
