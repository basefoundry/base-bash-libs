# Supported platform and shell matrix

This matrix is the release contract for Base Bash. A row is supported only
when the repository validation workflow and the release artifact checks are
green for that row. A missing optional tool is an explicit skip, not an
unreported pass.

| Dimension | Supported contract | Evidence |
| --- | --- | --- |
| Bash | 4.2.53 minimum; representative 4.4.23 and 5.0.18/5.2.37; current 5.x | Pinned networkless Bash containers, current runner validation, \`tests/compatibility-matrix.sh\`, deterministic property, artifact, and concurrency contracts |
| macOS | Pinned GitHub-hosted macOS 14 with Homebrew Bash; system Bash 3.2 is rejected with remediation | macOS validation and unsupported-system-Bash smoke |
| Linux/glibc | Pinned Ubuntu 24.04 runner and Bash 4.2/4.4/5.0/5.2 containers | Ubuntu validation and compatibility workflow |
| Linux/musl | Alpine/musl syntax and option-contract probe when the runner provides Docker | \`tests/compatibility-matrix.sh --container alpine\` |
| BSD userland | Best-effort portability checks; no release guarantee until a maintained CI runner is available | Explicitly reported as advisory |
| Locale | UTF-8 and \`C\` locale behavior for parsing, sorting, and diagnostics | Option and parser tests; caller owns locale selection |
| Filesystem | Local POSIX filesystem; symlink and race checks are fail-closed | cleanup, import, bundle, vendor, marker, and artifact-contract tests |
| Network | Core tests are networkless; GitHub/Homebrew integrations are optional and bounded | read-only workflow permissions, Docker \`--network none\`, retry tests |

## Strict-option combinations

Sourceable modules must preserve caller state under the supported combinations
\`(none)\`, \`-e\`, \`-u\`, \`pipefail\`, \`-eu\`, \`-ep\`, \`-up\`, and \`-eup\`.
The authoritative probe is \`tests/bash-option-contract.sh\`; release validation
runs it under the pinned Bash 4.2 image as well as the current runner Bash.

## Artifact modes

The same checks apply to source checkouts, Homebrew-style installed roots,
verified vendored roots, generated project kits, and deterministic standalone
bundles. \`tests/artifact-contract.sh\` runs all eight supported caller-option
combinations through the source, generated, vendored, and standalone paths;
\`scripts/library-bundle verify\` and \`scripts/vendor verify\` must pass before
an artifact is described as release-ready.

## Reproducible adversarial coverage

\`tests/property-contract.sh\` runs 128 deterministic, seeded cases covering
argv quoting, empty and glob-like fields, repeatable options, marker edits, and
command-like data. The seed is reported on failure so a downstream report can
replay the exact case without network access or a package manager.

\`tests/concurrency-contract.sh\` runs sixteen independent import and cleanup
workers in parallel and verifies unique managed temporary directories. Signal,
process-tree, and launcher cleanup behavior is covered by the launcher BATS
suite; benchmark evidence is checked by \`tests/benchmark-contract.sh\`.

Workflow formatting and action syntax are required in the separate Quality
workflow. Its shfmt and actionlint images are full-digest pinned and run with
network disabled, read-only mounts, dropped capabilities, and least-privilege
users. See [the CI policy](ci-policy.md) for the branch-protection contract.

## Caller responsibilities

Applications must select a supported Bash, avoid mutating framework-owned
\`BASE_BASH_LIBS_*\` state, provide permissions for requested filesystem changes,
and install optional commands such as \`git\`, \`gh\`, \`bats\`, \`shellcheck\`, and
\`shfmt\` when using integrations that require them. The framework never treats
the presence of an optional command as a reason to weaken core guarantees.
