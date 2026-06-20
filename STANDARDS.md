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

Do not split one library into internal concern files such as separate logging,
path, string, prompt, or command-runner fragments. That kind of split adds a
source-order and import graph for callers without improving the public library
contract.

A new library file is appropriate when the repository adds a distinct reusable
library boundary, such as the existing `file` and `git` libraries. Large
libraries should stay navigable through section ordering, consistent function
prefixes, README coverage, and focused tests rather than a shell module loader
or chained source fragments.
