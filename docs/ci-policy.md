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

## Required checks

The `main` branch must require these checks before merge:

- `Tests / Validate (macos-14)`
- `Tests / Validate (ubuntu-24.04)`
- `Tests / Compatibility (Bash 4.4.23)`
- `Tests / Compatibility (Bash 5.0.18)`
- `Tests / Compatibility (Bash 5.2.37)`
- `Tests / Compatibility smoke (Bash 4.2.53)`
- `Tests / Release gates (matrix and provenance)`
- `Quality / Quality gates`
- `Issue Branch Policy / Publish issue branch policy`

Require one approving review, dismiss stale approvals after new commits, and
require branches to be up to date before merging. Administrators should keep
the protection enforced; an emergency merge is an auditable exception, not a
replacement for the required checks.

## Emergency procedure

1. Record the incident, affected commit, approver, and reason in the pull
   request and the umbrella issue.
2. Use an administrator-only bypass only for a time-sensitive remediation.
3. Restore branch protection immediately and run the complete workflows on the
   resulting `main` commit.
4. Open a follow-up issue for every skipped check or review, with a concrete
   owner and due date.

## Platform claims

The hosted matrix covers current macOS, Linux/glibc, exact Bash 4.2.53, and
representative Bash 4.x and 5.x releases. Alpine/musl runs in the networkless
release gate. No maintained GitHub-hosted BSD runner is currently available;
BSD remains explicitly advisory until a maintained runner can execute the same
contract. A release must not describe advisory BSD evidence as a supported
guarantee.
