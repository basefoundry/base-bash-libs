# Bash support and validation quickstart

Use this page when making a first documentation, library, or integration
change. It identifies the supported shell, the smallest useful checks, and the
boundary between checkout validation and release-artifact validation.

## 1. Select a supported Bash

Base Bash requires Bash 4.2.53 or newer. Confirm the interpreter that will run
the checks before installing anything:

```bash
bash --version
```

On macOS, the system `/bin/bash` is Bash 3.2 and is not supported. Install and
select Homebrew Bash instead:

```bash
brew install bash bats-core shellcheck
"$(brew --prefix bash)/bin/bash" --version
"$(brew --prefix bash)/bin/bash" tests/validate.sh
```

On Linux, use the installed `bash` only when its version is at least 4.2.53.
Do not run the library with `sh`, `dash`, or another shell that is not Bash.
BSD and other Unix systems are best-effort environments rather than release
guarantees; use the [support policy](support-policy.md) for the complete
boundary.

If the version is too old, install a supported Bash and invoke the checks with
that interpreter. If `bats` or `shellcheck` is missing, install those tools or
report the missing prerequisite as an environment failure; do not weaken the
validation command or claim a partial pass.

## 2. Run the focused contributor checks

From the repository root, the supported validation entry point is:

```bash
./tests/validate.sh
```

The script checks the repository baseline, documentation, shell quality,
compatibility, API and artifact contracts, BATS suites, and release
invariants. For a quick iteration before the full suite, these focused checks
exercise the runtime and consumer boundary:

```bash
bash tests/bash-option-contract.sh
bash tests/compatibility-matrix.sh
bats tests/consumer-kit/tests/consumer_kit.bats
```

Run the full suite before opening a pull request. Record the Bash version, OS,
exact command, exit status, and relevant stdout/stderr when a check fails.
Never include secrets, tokens, private paths, or unredacted environment dumps
in a public issue; use the [security policy](../SECURITY.md) for a security
sensitive report.

## 3. Know which artifact is being validated

| Validation target | First check | What it proves |
| --- | --- | --- |
| Source checkout | `./tests/validate.sh` | The current repository and its source libraries satisfy the complete project gates. |
| Consumer fixture | `bats tests/consumer-kit/tests/consumer_kit.bats` | A small application can use the public consumer helpers and keep stdout separate from diagnostics. |
| Vendored or standalone artifact | `bats tests/vendor.bats` | Generated, vendored, bundled, and standalone layouts preserve the release identity and launcher behavior. |
| Release bundle in isolation | `scripts/library-bundle verify <bundle-dir>` | A deterministic bundle is internally complete and matches its recorded manifest. |

The source checkout is a moving development input. A vendored tree, bundle, or
release archive must instead be validated against its recorded version, full
commit, checksum, and provenance; see [pinned consumption](pinned-consumption.md)
and [single-file distribution](single-file-distribution.md). The
[support matrix](support-matrix.md) is the canonical description of supported
platforms and optional tools.

## 4. Where to go next

Use the [full support policy](support-policy.md) for runtime guarantees, the
[CI policy](ci-policy.md) for hosted validation, and
[CONTRIBUTING.md](../CONTRIBUTING.md) for the issue and pull-request workflow.
Keep the Bash floor and platform matrix unchanged unless a separate issue
explicitly changes that release contract.
