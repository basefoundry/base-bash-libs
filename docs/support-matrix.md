# Supported platform and shell matrix

This matrix is the release contract for Base Bash. A row is supported only
when the repository validation workflow and the release artifact checks are
green for that row. A missing optional tool is an explicit skip, not an
unreported pass.

| Dimension | Supported contract | Evidence |
| --- | --- | --- |
| Bash | 4.2.53 minimum; representative 4.x; current 5.x | Pinned networkless Bash 4.2 smoke, current runner validation, \`tests/compatibility-matrix.sh\` |
| macOS | Current GitHub-hosted macOS with Homebrew Bash; system Bash 3.2 is rejected with remediation | macOS validation and unsupported-system-Bash smoke |
| Linux/glibc | Ubuntu runner and pinned Bash 4.2 container | Ubuntu validation and compatibility workflow |
| Linux/musl | Alpine/musl syntax and option-contract probe when the runner provides Docker | \`tests/compatibility-matrix.sh --container alpine\` |
| BSD userland | Best-effort portability checks; no release guarantee until a maintained CI runner is available | Explicitly reported as advisory |
| Locale | UTF-8 and \`C\` locale behavior for parsing, sorting, and diagnostics | Option and parser tests; caller owns locale selection |
| Filesystem | Local POSIX filesystem; symlink and race checks are fail-closed | cleanup, import, bundle, and vendor tests |
| Network | Core tests are networkless; GitHub/Homebrew integrations are optional and bounded | workflow permissions, Docker \`--network none\`, retry tests |

## Strict-option combinations

Sourceable modules must preserve caller state under the supported combinations
\`(none)\`, \`-e\`, \`-u\`, \`pipefail\`, \`-eu\`, \`-ep\`, \`-up\`, and \`-eup\`.
The authoritative probe is \`tests/bash-option-contract.sh\`; release validation
runs it under the pinned Bash 4.2 image as well as the current runner Bash.

## Artifact modes

The same checks apply to source checkouts, Homebrew-style installed roots,
verified vendored roots, generated project kits, and deterministic standalone
bundles. \`scripts/library-bundle verify\` and \`scripts/vendor verify\` must pass
before an artifact is described as release-ready.

## Caller responsibilities

Applications must select a supported Bash, avoid mutating framework-owned
\`BASE_BASH_LIBS_*\` state, provide permissions for requested filesystem changes,
and install optional commands such as \`git\`, \`gh\`, \`bats\`, \`shellcheck\`, and
\`shfmt\` when using integrations that require them. The framework never treats
the presence of an optional command as a reason to weaken core guarantees.
