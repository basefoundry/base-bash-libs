# base-bash-libs

| Version | License | Install | Release notes |
| --- | --- | --- | --- |
| `1.4.0` | [Apache-2.0](LICENSE) | `brew install basefoundry/base/base-bash-libs` | [v1.4.0](https://github.com/basefoundry/base-bash-libs/releases/tag/v1.4.0) |

Reusable Bash standard library for reliable shell scripts.

base-bash-libs provides sourceable Bash libraries for logging, error handling,
safe command execution, filesystem edits, Git helpers, string utilities, temp
paths, cleanup hooks, and import conventions. It is extracted from
[Base](https://github.com/basefoundry/base), but can be installed and used
independently through Homebrew, source checkouts, vendored copies, or git
submodules.

Requires Bash 4.2+. On macOS, use Homebrew Bash instead of the system `/bin/bash`.

## Libraries

- [`lib/bash/std/lib_std.sh`](lib/bash/std/README.md)
  Foundation helpers for logging, error handling, command execution, PATH
  updates, assertions, prompts, imports, and the public
  `BASE_BASH_LIBS_VERSION` constant.
- [`lib/bash/file/lib_file.sh`](lib/bash/file/README.md)
  File editing helpers built on the stdlib, including idempotent
  marker-delimited file section updates.
- [`lib/bash/git/lib_git.sh`](lib/bash/git/README.md)
  Git helper functions built on the stdlib for default-branch, worktree,
  upstream, remote, repository update, and script freshness checks.
- [`lib/bash/gh/lib_gh.sh`](lib/bash/gh/README.md)
  GitHub CLI helper functions built on the stdlib for command readiness,
  authentication diagnostics, remote parsing, API retries, and checked `gh`
  execution.
- [`lib/bash/str/lib_str.sh`](lib/bash/str/README.md)
  String helpers built on the stdlib for case conversion, trimming,
  predicates, splitting, and joining.
- [`lib/bash/arg/lib_arg.sh`](lib/bash/arg/README.md)
  Argument parsing helpers built on the stdlib for exact flag, scalar value,
  and repeatable value options without hidden parser globals.
- [`lib/bash/list/lib_list.sh`](lib/bash/list/README.md)
  Indexed-array helpers built on the stdlib for in-place mutation,
  membership checks, deduplication, and length results.
- [`lib/bash/cli/lib_cli.sh`](lib/bash/cli/README.md)
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
See [`docs/single-file-distribution.md`](docs/single-file-distribution.md) for
the contributor and release-artifact workflow.
Offline immutable vendoring, atomic updates/rollback, and standalone assembly
are provided by [`scripts/vendor`](scripts/vendor); no runtime network access
or `curl | bash` installer is used.
The v2 API charter, effect/status contract, and complete public-surface audit
are in [`docs/v2-api-contract.md`](docs/v2-api-contract.md). The symbol-level
mapping and migration aid are in [`docs/v2-symbol-map.md`](docs/v2-symbol-map.md).
Start with the [versioned v2 documentation](docs/README.md), especially the
[five-minute quickstart](docs/v2/quickstart.md) and the
[v1.4.0-to-v2 migration guide](docs/v2/migration-v1.4-to-v2.md).
See the [support policy](docs/support-policy.md),
[threat model](docs/threat-model.md), and [security policy](SECURITY.md) before
embedding the framework in a production or privileged workflow.
The machine-readable module/API contract is in
[`base_api_manifest.yaml`](base_api_manifest.yaml), with its schema documented
in [`docs/api-manifest-schema.md`](docs/api-manifest-schema.md) and its
generated reference in [`docs/api-reference.md`](docs/api-reference.md).
The supported-runtime, stability, and caller-responsibility contract is in
[`docs/support-policy.md`](docs/support-policy.md); the security reporting
process and threat model are in [`SECURITY.md`](SECURITY.md) and
[`docs/threat-model.md`](docs/threat-model.md).

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
git clone https://github.com/basefoundry/base-bash-libs.git vendor/base-bash-libs
git -C vendor/base-bash-libs checkout --detach \
  2c5ef2c3a9edfbe2cf68d0645be65b920255abff
test "$(git -C vendor/base-bash-libs rev-parse HEAD)" = \
  2c5ef2c3a9edfbe2cf68d0645be65b920255abff
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

`v1.4.0` remains stable during the clean-break v2 development train. The sole
next stable target is `v2.0.0`; there will be no stable v1.5.0 or version reset
to 0.x. See the [versioning and release-line policy](docs/versioning-policy.md)
for prerelease identifiers, publication gates, the withdrawn July 2026 v2
event, immutable consumption, and the post-GA support contract.

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
