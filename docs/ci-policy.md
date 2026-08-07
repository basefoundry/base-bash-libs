# CI and default-branch policy

The `Tests` and `Quality` workflows are release gates, not advisory examples.
They run with `contents: read`, cancel superseded runs, and keep network access
out of the containerized compatibility and lint checks. Actions and container
images are pinned to full immutable commit or digest references; changing one
requires a reviewable dependency update.

The shfmt gate checks every Bash source changed by a pull request (and the
latest commit on `main`). This prevents new formatting debt while allowing the
existing v1-to-v2 codebase to be cleaned incrementally; touching a legacy file
puts its complete contents under the formatter gate.

## Default-branch baseline

`base-bash-libs` follows the same modest default-branch baseline as Base:

- pull requests are required and merges are squash-only;
- the `Base branch naming` ruleset protects non-default branches;
- the `Base default branch protection` ruleset requires the trusted
  `base/issue-branch-policy` status, and prevents deletion and non-fast-forward
  updates;
- administrators remain subject to branch protection; and
- no approval count or individual Tests/Quality job is a default merge
  requirement.

This is a merge-policy choice, not a validation waiver. The `Tests` and
`Quality` workflows still run on pull requests and `main`, and they remain
release gates. Run the complete local validation and release readiness checks
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
