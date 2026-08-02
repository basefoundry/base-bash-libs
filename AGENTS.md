# Agent Guidance

Read [CONTRIBUTING.md](CONTRIBUTING.md) for the issue, worktree, pull request,
validation, and cleanup workflow. Read [STANDARDS.md](STANDARDS.md) before
changing the shell libraries.

## Release Work

Read [docs/release-process.md](docs/release-process.md) before doing release
work. Ordinary pull requests must leave `VERSION` unchanged; a release-prep
pull request owns the version, README release row, and changelog transition.

The repository release contract is declared in `base_manifest.yaml`, and the
active release-line policy is documented in `docs/versioning-policy.md`. Use
the repository-owned `scripts/release check|plan|notes|publish` guard after the
release preparation pull request is merged. Do not bypass it with direct
`basectl release` calls. Complete the Homebrew and Base downstream handoffs
documented in the release process.

## Shell Changes

- Keep each public sourceable library in its single-file boundary.
- Do not add `set -e`, `set -u`, or `set -o pipefail` to production libraries.
- Add focused BATS coverage for behavior changes and run `./tests/validate.sh`.
