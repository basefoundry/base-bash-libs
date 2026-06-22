# base-bash-libs

| Version | License | Install | Release notes |
| --- | --- | --- | --- |
| `1.0.0` | [Apache-2.0](LICENSE) | `brew install basefoundry/base/base-bash-libs` | [v1.0.0](https://github.com/basefoundry/base-bash-libs/releases/tag/v1.0.0) |

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
  Git helper functions built on the stdlib for lightweight repository
  inspection, update, and script freshness checks.
- [`lib/bash/str/lib_str.sh`](lib/bash/str/README.md)
  String helpers built on the stdlib for case conversion, trimming,
  predicates, splitting, joining, and array membership checks.

See [`lib/bash/README.md`](lib/bash/README.md) for the package layout.

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
printf 'base-bash-libs version: %s\n' "$BASE_BASH_LIBS_VERSION"
```

Load companion libraries with absolute imports from the same package:

```bash
import "$base_bash_libs_prefix/libexec/lib/bash/file/lib_file.sh"
import "$base_bash_libs_prefix/libexec/lib/bash/git/lib_git.sh"
import "$base_bash_libs_prefix/libexec/lib/bash/str/lib_str.sh"
```

### Source Checkout

You can use a git checkout, tarball extract, or copied source tree without
Homebrew. Keep the repository layout intact so `lib_std.sh` can find the root
`VERSION` file:

```bash
git clone https://github.com/basefoundry/base-bash-libs.git vendor/base-bash-libs
```

Source the stdlib from that checkout:

```bash
base_bash_libs_dir="$PWD/vendor/base-bash-libs"
source "$base_bash_libs_dir/lib/bash/std/lib_std.sh"
printf 'base-bash-libs version: %s\n' "$BASE_BASH_LIBS_VERSION"
```

Load companion libraries with absolute imports from the same checkout:

```bash
import "$base_bash_libs_dir/lib/bash/file/lib_file.sh"
import "$base_bash_libs_dir/lib/bash/git/lib_git.sh"
import "$base_bash_libs_dir/lib/bash/str/lib_str.sh"
```

### Vendored or Submodule Layout

For projects that vendor dependencies or use git submodules, place this
repository anywhere stable inside your project and source it by absolute path:

```bash
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
base_bash_libs_dir="$project_root/vendor/base-bash-libs"

source "$base_bash_libs_dir/lib/bash/std/lib_std.sh"
import "$base_bash_libs_dir/lib/bash/file/lib_file.sh"
import "$base_bash_libs_dir/lib/bash/git/lib_git.sh"
import "$base_bash_libs_dir/lib/bash/str/lib_str.sh"
```

After `lib_std.sh` is sourced, `BASE_BASH_LIBS_VERSION` contains the package
version from the repository/package `VERSION` file. Downstream scripts can use
that readonly constant when they need to display the loaded library version.
Use `base_bash_libs_require_version` to require a minimum library version:

```bash
base_bash_libs_require_version 1.1.0
```

See `examples/std-usage.sh` for a small standalone script that sources the
stdlib, imports the file helpers, logs progress, and runs a checked command.

## Versioning

The repo-root `VERSION` file is the source of truth for the package version.
The top strip in this README and the runtime `BASE_BASH_LIBS_VERSION` constant
are validated against that file.

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
