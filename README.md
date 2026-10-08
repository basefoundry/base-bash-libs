# base-bash-libs

[![Tests](https://img.shields.io/github/actions/workflow/status/basefoundry/base-bash-libs/tests.yml?branch=main&label=tests)](https://github.com/basefoundry/base-bash-libs/actions/workflows/tests.yml)
[![Release](https://img.shields.io/github/v/release/basefoundry/base-bash-libs?sort=semver&label=release)](https://github.com/basefoundry/base-bash-libs/releases)
[![Bash](https://img.shields.io/badge/Bash-4.2.53%2B-4EAA25?logo=gnubash&logoColor=white)](docs/support-matrix.md)

| Version | License | Install | Release notes |
| --- | --- | --- | --- |
| `2.2.1` | [Apache-2.0](LICENSE) | `brew install basefoundry/base/base-bash-libs` | [v2.2.1](https://github.com/basefoundry/base-bash-libs/releases/tag/v2.2.1) |

The v2.2.1 release is published with a deterministic [bundle archive](https://github.com/basefoundry/base-bash-libs/releases/download/v2.2.1/base-bash-libs-v2.2.1.tar.gz), [checksum manifest](https://github.com/basefoundry/base-bash-libs/releases/download/v2.2.1/base-bash-libs-v2.2.1.SHA256SUMS), [SPDX SBOM](https://github.com/basefoundry/base-bash-libs/releases/download/v2.2.1/base-bash-libs-v2.2.1.spdx.json), and [provenance statement](https://github.com/basefoundry/base-bash-libs/releases/download/v2.2.1/base-bash-libs-v2.2.1.provenance.json). First-party consumers and Homebrew can promote to its exact immutable commit through the coordinated release handoff; the original v2.0.0 cutover is recorded in completed issue #240.

Base Bash is a Bash 4.2+ application framework and standard library for
declarative CLIs, typed configuration, lifecycle-safe cleanup, and reliable
shell automation.

It gives applications safe execution and filesystem primitives, a structured
command contract, configuration that is data-only and precedence-aware, and
immutable package identity. It is extracted from
[Base](https://github.com/basefoundry/base), but can be installed and used
independently through Homebrew, source checkouts, vendored copies, or git
submodules.

A minimal v2 application declares its interface and policy before dispatch:

<!-- BEGIN README APPLICATION EXAMPLE -->
```bash
#!/usr/bin/env base-bash

base_launcher_import_base_bash_lib cli/lib_cli.sh app/lib_app.sh
base_cli_model_init hello name=hello version=1.0.0
base_cli_command hello greet "Greet someone" handler=hello_dispatch
base_app_init hello_policy name=hello
base_app_config_define hello_policy name string default=world env=HELLO_NAME
base_app_add_standard_options hello ""
hello_cleanup() { :; }
hello_execute() {
    local name=""
    base_app_apply_standard_options hello_policy
    base_app_config_load hello_policy || return $?
    base_app_hook hello_policy cleanup hello_cleanup hello_cleanup || return $?
    base_app_config_get hello_policy name name || return $?
    printf 'hello=%s\n' "$name"
}
hello_dispatch() { base_app_run hello_policy hello_execute; }
main() { base_cli_run hello -- "$@"; }
```
<!-- END README APPLICATION EXAMPLE -->

Run it with `HELLO_NAME=Base ./hello greet` to get `hello=Base`. Start with
the [v2 quickstart](docs/v2/quickstart.md) and then see the
[pinned Beacon reference consumer](https://github.com/basefoundry/base-bash-libs-demo/blob/v0.1.2/README.md)
for a complete offline application.

Requires Bash 4.2.53+. On macOS, use Homebrew Bash instead of the system `/bin/bash`.
The shared Base ecosystem boundary is maintained in the [Base ecosystem
platform, license, and release policy](https://github.com/basefoundry/base/blob/main/docs/ecosystem-policy.md).

## Libraries

The libraries are layered from foundation to application. Start with `std`
for portable primitives, add the building blocks your script needs, and use
`cli` plus `app` when it becomes a user-facing application.

- **Foundation:** [`lib/bash/std/lib_std.sh`](lib/bash/std/README.md)
  Foundation helpers for logging, error handling, command execution, PATH
  updates, assertions, prompts, imports, and the public
  `BASE_BASH_LIBS_VERSION` constant.
- **Building blocks:** [`lib/bash/process/lib_process.sh`](lib/bash/process/README.md)
  Preview-only process-supervision primitives for owner-guardian liveness and
  asynchronous cleanup, layered on the stdlib. This post-GA module first
  shipped in `v2.1.0` and is included in the current immutable `v2.2.1`
  release, but is not part of the stable API.
- [`lib/bash/file/lib_file.sh`](lib/bash/file/README.md)
  File editing helpers built on the stdlib, including idempotent
  marker-delimited file section updates.
- [`lib/bash/git/lib_git.sh`](lib/bash/git/README.md)
  Git helper functions built on the stdlib for default-branch, worktree,
  upstream, remote, repository update, and script freshness checks.
- [`lib/bash/gh/lib_gh.sh`](lib/bash/gh/README.md)
  GitHub CLI helper functions, built on the stdlib and process module for
  command readiness, authentication diagnostics, remote parsing, API retries,
  and checked `gh` execution. The public surface remains stable since
  `v2.0.0`; the current implementation uses the preview `process` module
  privately.
- [`lib/bash/str/lib_str.sh`](lib/bash/str/README.md)
  String helpers built on the stdlib for case conversion, trimming,
  predicates, splitting, and joining.
- [`lib/bash/arg/lib_arg.sh`](lib/bash/arg/README.md)
  Argument parsing helpers built on the stdlib for exact flag, scalar value,
  and repeatable value options without hidden parser globals.
- [`lib/bash/list/lib_list.sh`](lib/bash/list/README.md)
  Indexed-array helpers built on the stdlib for in-place mutation,
  membership checks, deduplication, and length results.
- **Application framework:** [`lib/bash/cli/lib_cli.sh`](lib/bash/cli/README.md)
  Declarative command contracts with nested subcommands, validation, help,
  completion, and a handler boundary for Bash applications.
- [`lib/bash/app/lib_app.sh`](lib/bash/app/README.md)
  Optional typed configuration, standard application options, prompt policy,
  and exactly-once lifecycle hooks.

See [`lib/bash/README.md`](lib/bash/README.md) for the package layout.
The reusable consumer conformance helpers and offline fixture are in
[`tests/consumer-kit`](tests/consumer-kit/README.md).
Deterministic single-file validation and auditable directory bundles are
provided by [`scripts/library-bundle`](scripts/library-bundle).
Production-shaped reference applications and transparent startup benchmarks
are in [`examples/reference-apps`](examples/reference-apps) and
[`benchmarks/reference-apps.sh`](benchmarks/reference-apps.sh).
The isolated first-party
[`base-bash-libs-demo`](https://github.com/basefoundry/base-bash-libs-demo/blob/v0.1.2/README.md)
repository is a five-minute, offline Beacon application that shows the v2
CLI, configuration, lifecycle, and cleanup contracts in a complete consumer.
Start with its [pinned five-minute tutorial](https://github.com/basefoundry/base-bash-libs-demo/blob/v0.1.2/docs/five-minute-tutorial.md),
then read [why Base Bash](https://github.com/basefoundry/base-bash-libs-demo/blob/v0.1.2/docs/why-base-bash-libs.md)
and the [adoption decision guide](https://github.com/basefoundry/base-bash-libs-demo/blob/v0.1.2/docs/should-i-use-base-bash-libs.md).
The repository also consumes the canonical release bundle as a downstream
compatibility canary. It is regression evidence, not an independent-adoption
claim.
For the rest of the documentation, use the map near the end of this README.

## When to reach for Base Bash

Use Base Bash when Bash is the runtime you have to ship and you still need
production-grade structure: macOS or Linux provisioning and init scripts, CI
glue on hosts where no other language runtime is guaranteed, embedded recovery
or bootstrap environments, and small operational tools that must remain
sourceable, auditable, and easy to vendor.

If you can choose a richer runtime, choose the tool that best fits the job.
Base Bash is deliberately for the cases where leaving Bash is not practical;
it adds safe execution, typed configuration, declarative CLI contracts,
cleanup/lifecycle boundaries, and immutable package identity to that constraint.

The shortest path is the [five-minute quickstart](docs/v2/quickstart.md),
followed by the examples and the non-mutating `base-bash check` command.

## Installation and Usage

### Homebrew

Install the library package from the Base Homebrew tap:

```bash
brew trust basefoundry/base
brew install basefoundry/base/base-bash-libs
```

The trust step is required on Homebrew versions that block formulae from
non-official taps until the tap is trusted. It is safe to run again on machines
that already trust `basefoundry/base`.

Source the installed stdlib from the Homebrew prefix:

```bash
base_bash_libs_prefix="$(brew --prefix basefoundry/base/base-bash-libs)"
source "$base_bash_libs_prefix/libexec/lib/bash/std/lib_std.sh"
declare -a app_args=()
base_init app_args --source "${BASH_SOURCE[0]}" -- "$@"
printf 'base-bash-libs version: %s\n' "$BASE_BASH_LIBS_VERSION"
```

Homebrew installs the standalone `base-bash` launcher on `PATH`. Use it when a
script should run with the stdlib preloaded from its shebang:

```bash
#!/usr/bin/env base-bash

base_std_import str/lib_str.sh

main() {
    local name="  Example  "
    base_str_trim name
    base_std_log_info "Running with base-bash-libs $BASE_BASH_LIBS_VERSION"
    base_std_run echo "$name"
}
```

The launcher contract is intentionally conventional: `base-bash --help` and
`base-bash --version` return `0` with stdout data, `base-bash check` performs a
non-mutating installation/package diagnostic, and malformed launcher usage
returns `2` with stderr diagnostics. Use `base-bash --` before a script path
that begins with `-`; application argv and the application `main` status are
preserved. See the [v2 launcher contract](docs/v2-api-contract.md#6-launcher-contract-v2-rc)
for lifecycle, cleanup, signal, and wrapper-flag details.

Load companion libraries with package-relative imports from the loaded package:

```bash
base_std_import file/lib_file.sh git/lib_git.sh gh/lib_gh.sh str/lib_str.sh arg/lib_arg.sh list/lib_list.sh
```

### Source Checkout

You can use a git checkout, tarball extract, or copied source tree without
Homebrew. Keep the repository layout intact so `lib_std.sh` can find the root
`VERSION` file:

Pin the checkout to the full current release commit instead of consuming the
moving default branch:

```bash
base_bash_libs_ref='v2.2.1'
mkdir -p vendor
git clone https://github.com/basefoundry/base-bash-libs.git vendor/base-bash-libs
git -C vendor/base-bash-libs fetch --tags origin "$base_bash_libs_ref"
git -C vendor/base-bash-libs checkout --detach "$base_bash_libs_ref"
base_bash_libs_commit="$(git -C vendor/base-bash-libs rev-parse HEAD)"
test "$(git -C vendor/base-bash-libs rev-parse HEAD)" = "$base_bash_libs_commit"
```

Source the stdlib from that checkout:

```bash
base_bash_libs_dir="$PWD/vendor/base-bash-libs"
source "$base_bash_libs_dir/lib/bash/std/lib_std.sh"
declare -a app_args=()
base_init app_args --source "${BASH_SOURCE[0]}" -- "$@"
printf 'base-bash-libs version: %s\n' "$BASE_BASH_LIBS_VERSION"
```

Load companion libraries with package-relative imports from the same checkout:

```bash
base_std_import file/lib_file.sh git/lib_git.sh gh/lib_gh.sh str/lib_str.sh arg/lib_arg.sh list/lib_list.sh
```

You can also run source-checkout scripts through the launcher:

```bash
vendor/base-bash-libs/bin/base-bash ./scripts/tool.sh
```

### Vendored or Submodule Layout

For projects that vendor dependencies or use git submodules, place this
repository anywhere stable inside your project and source it by absolute path:

```bash
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
base_bash_libs_dir="$project_root/vendor/base-bash-libs"

source "$base_bash_libs_dir/lib/bash/std/lib_std.sh"
declare -a app_args=()
base_init app_args --source "${BASH_SOURCE[0]}" -- "$@"
base_std_import file/lib_file.sh git/lib_git.sh gh/lib_gh.sh str/lib_str.sh arg/lib_arg.sh list/lib_list.sh
```

After `lib_std.sh` is sourced, `BASE_BASH_LIBS_VERSION` contains the package
version from the repository/package `VERSION` file, or from the embedded
`lib/bash/base-bash-libs.release` metadata when a supported artifact contains
only the library tree. Downstream scripts can use that readonly constant when
they need to display the loaded library version.

The stdlib also exposes `BASE_BASH_LIBS_COMMIT`,
`BASE_BASH_LIBS_DIRTY_STATE`, and `BASE_BASH_LIBS_PROVENANCE`. Checkouts report
their actual full commit and clean/dirty state; release archives, Homebrew
installs, vendored trees, and standalone copies use the identity embedded in
`base-bash-libs.release` and never infer a commit from the caller's cwd.
Use `base_require_version` to require a minimum library version:

```bash
base_require_version 1.4.0
```

## Examples

- [`examples/std-usage.sh`](examples/std-usage.sh)
  Small standalone script that sources the stdlib, imports the file helpers,
  logs progress, and runs a checked command.
- [`examples/cookbook-cleanup-temp.sh`](examples/cookbook-cleanup-temp.sh)
  Cleanup hooks, temp paths, version checks, command resolution, timeout, and
  checked command execution.
- [`examples/cookbook-args-lists-strings.sh`](examples/cookbook-args-lists-strings.sh)
  Argument parsing, list helpers, and in-place string transformations working
  together.

## Versioning

The repo-root `VERSION` file is the source of truth for the package version.
The top strip in this README and the runtime `BASE_BASH_LIBS_VERSION` constant
are validated against that file.

`v2.2.1` is the current stable release. It is a post-GA release on the v2 line;
SemVer compatibility guarantees began at v2.0.0. See the [versioning and
release-line policy](docs/versioning-policy.md) for immutable consumption and
the post-GA support contract.

The `process` module remains preview-only. It first shipped in `v2.1.0` and is
included in `v2.2.1`, but is not part of the stable API; consumers pinned to
`v2.0.0` do not have it.

Pinned checkout, archive, Homebrew, vendored, and standalone consumption is
documented in [`docs/pinned-consumption.md`](docs/pinned-consumption.md).
Release preparation and downstream Homebrew/Base handoffs are documented in
[`docs/release-process.md`](docs/release-process.md). The machine-readable
release contract lives in [`base_manifest.yaml`](base_manifest.yaml); the
machine-readable API and module contract lives in
[`base_api_manifest.yaml`](base_api_manifest.yaml).

## License

base-bash-libs is licensed under [Apache-2.0](LICENSE). See [NOTICE](NOTICE) for
the project copyright notice.

## Validation

Run the full local validation suite:

```bash
./tests/validate.sh
```

The suite expects `bats` and `shellcheck` to be installed. On macOS:

```bash
brew install bats-core shellcheck
```

Local validation runs the logging compatibility smoke on the installed
supported Bash. CI runs the same script on the exact minimum runtime, Bash
4.2.53, using a digest-pinned Docker Official Image.

## Documentation map

Start with the [versioned v2 documentation](docs/README.md), especially the
[five-minute quickstart](docs/v2/quickstart.md) and the
[v1.4.0-to-v2 migration guide](docs/v2/migration-v1.4-to-v2.md).

- [API charter and status contract](docs/v2-api-contract.md)
- [API symbol map](docs/v2-symbol-map.md)
- [Generated API reference](docs/api-reference.md) and
  [manifest schema](docs/api-manifest-schema.md)
- [Pinned consumption](docs/pinned-consumption.md),
  [vendor workflow](docs/vendor-workflow.md), and
  [single-file distribution](docs/single-file-distribution.md)
- [Integrations](docs/integrations.md) for optional generator, Bats, formatter,
  and package-channel recipes
- [Support matrix](docs/support-matrix.md), [support policy](docs/support-policy.md),
  [threat model](docs/threat-model.md), and [security policy](SECURITY.md)
- [Bash support and validation quickstart](docs/bash-validation-quickstart.md)
- [Consumer-kit contribution path](docs/consumer-kit-contribution.md)
- [Community participation and independent validation](docs/community.md),
  [GitHub Discussions](https://github.com/basefoundry/base-bash-libs/discussions)
  for design questions and usage support, and [GitHub Issues](https://github.com/basefoundry/base-bash-libs/issues)
  for tracked work. See also [who uses Base Bash](docs/who-uses-base-bash.md)
  and the
  [consumer-validation status](docs/consumer-validation-status.md)
- New contributors can start with the repository's
  [good first issues](https://github.com/basefoundry/base-bash-libs/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22).
- [Versioning policy](docs/versioning-policy.md) and
  [release process](docs/release-process.md)

The first-party v2 release handoff is tracked in
[`first-party-cutover.yaml`](first-party-cutover.yaml) and checked by
[`scripts/first-party-cutover`](scripts/first-party-cutover). The machine-readable
release contract lives in [`base_manifest.yaml`](base_manifest.yaml), and the
machine-readable module/API contract lives in
[`base_api_manifest.yaml`](base_api_manifest.yaml).
The historical promotion sequence and verification record are documented in
[`docs/first-party-cutover.md`](docs/first-party-cutover.md).

## Base

This repository is managed by [Base](https://github.com/basefoundry/base).
Base is useful for developing this repository, but it is not required to consume
the Bash libraries from Homebrew, a source checkout, a vendored copy, or a git
submodule.

Common commands:

```bash
basectl setup base-bash-libs
basectl check base-bash-libs
basectl doctor base-bash-libs
basectl test base-bash-libs
```
