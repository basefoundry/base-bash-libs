# base-bash-libs Standards

`base-bash-libs` inherits the Base shell standards as its upstream policy. See
[Base Standards](https://github.com/basefoundry/base/blob/HEAD/STANDARDS.md),
especially the
[single-file library boundary](https://github.com/basefoundry/base/blob/HEAD/STANDARDS.md#single-file-library-boundary)
guidance.

## Shell Library Shape

Each public sourceable Bash library in this repository should remain a single
physical `.sh` file at its library boundary:

- `lib/bash/std/lib_std.sh`
- `lib/bash/file/lib_file.sh`
- `lib/bash/git/lib_git.sh`
- `lib/bash/gh/lib_gh.sh`
- `lib/bash/str/lib_str.sh`
- `lib/bash/arg/lib_arg.sh`
- `lib/bash/list/lib_list.sh`

Do not split one library into internal concern files such as separate logging,
path, string, prompt, or command-runner fragments. That kind of split adds a
source-order and import graph for callers without improving the public library
contract.

A new library file is appropriate when the repository adds a distinct reusable
library boundary, such as the existing `file` and `git` libraries. Large
libraries should stay navigable through section ordering, consistent function
prefixes, README coverage, and focused tests rather than a shell module loader
or chained source fragments.

## Namespace and embedding contract

The v2 public namespace is deliberately collision-resistant so a library can
be sourced into an existing application without taking generic names:

- Public functions use `base_bash_libs_<module>_<name>` (with the two stdlib
  lifecycle exceptions documented in `lib/bash/README.md`).
- Framework-owned globals, environment controls, metadata, and load guards use
  `BASE_BASH_LIBS_...`.
- Internal functions use `__base_bash_libs_<module>_...__` and are not callable
  application API.

Generic v1 aliases are not retained in v2. Any intentional caller-owned
variables such as `PATH`, `NO_COLOR`, `TMPDIR`, `GH_TOKEN`, and `TZ` remain
outside this namespace and are documented as inputs rather than framework
state. Keep the complete migration map in sync with the source and run the
namespace collision tests when adding a new public symbol.
