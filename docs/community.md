# Community and maintainer model

## Support channels

- Use GitHub Issues for reproducible bugs, documentation gaps, and roadmap
  work. The templates request the minimum environment and validation details.
- Use GitHub Discussions (when enabled for the repository) for design questions,
  usage patterns, and comparisons that do not need a code change.
- Use the private security workflow in [`SECURITY.md`](../SECURITY.md) for
  vulnerabilities or sensitive conduct concerns.

Normal contributions may come from a public fork and may be submitted with
standard Git, GitHub, Bats, and ShellCheck tooling. `basectl`, dedicated
worktrees, and a pre-existing issue are helpful but not prerequisites for a
small fix. Required CI and the review checklist remain mandatory.

## Review and decisions

Pull requests should explain scope, public behavior, tests, compatibility, and
security impact. Maintainers seek consensus, record tradeoffs in the PR, and
use the roadmap issue for cross-cutting decisions. A maintainer may request a
design issue when a change affects the public API or release contract.

## Release and conflict process

Release changes follow `docs/release-process.md` and the immutable artifact
policy. Conflicts are handled first by a maintainer discussion, then by a
documented decision in the PR or roadmap issue. A maintainer may pause a PR for
security, conduct, or release-integrity reasons and must explain the reason.

## Succession

The project should have at least two active maintainers with permission to
review, release, and respond to security reports. A maintainer who steps back
documents handoff of repository administration, signing/attestation access,
Homebrew coordination, and private-report contacts. If no maintainer is
available, the public repository remains read-only until a successor is
recorded in this file and the GitHub organization settings.
