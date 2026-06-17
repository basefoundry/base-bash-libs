# base-bash-libs

Reusable Bash libraries extracted from
[Base](https://github.com/codeforester/base).

This repository provides sourceable Bash libraries for scripts that want Base's
logging, command execution, filesystem, and Git helper conventions without
adopting the full Base workspace control plane.

## Libraries

- `lib/bash/std/lib_std.sh`
  Foundation helpers for logging, error handling, command execution, PATH
  updates, assertions, prompts, and imports.
- `lib/bash/file/lib_file.sh`
  File editing helpers built on the stdlib.
- `lib/bash/git/lib_git.sh`
  Git helper functions built on the stdlib.

## Usage

Source the stdlib from an absolute path:

```bash
source "/path/to/base-bash-libs/lib/bash/std/lib_std.sh"
```

Load companion libraries with absolute imports:

```bash
import "/path/to/base-bash-libs/lib/bash/file/lib_file.sh"
import "/path/to/base-bash-libs/lib/bash/git/lib_git.sh"
```

See `examples/std-usage.sh` for a small standalone script that sources the
stdlib, imports the file helpers, logs progress, and runs a checked command.

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

This repository is managed by [Base](https://github.com/codeforester/base).

Common commands:

```bash
basectl setup base-bash-libs
basectl check base-bash-libs
basectl doctor base-bash-libs
basectl test base-bash-libs
```
