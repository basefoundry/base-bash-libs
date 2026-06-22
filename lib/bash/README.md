# Bash Libraries

Reusable Bash libraries for command wrappers and other Bash tooling.

## Layout

- `std/`
  Foundation library with logging, error handling, PATH helpers, and other
  shared Bash primitives.
- `git/`
  Git-related helpers built on top of the stdlib.
- `file/`
  File-editing helpers built on top of the stdlib.
- `str/`
  String helpers built on top of the stdlib.
- `arg/`
  Argument parsing helpers built on top of the stdlib.
- `list/`
  Indexed-array helpers built on top of the stdlib.
- `tests/`
  Common BATS helpers for Bash library test suites.

The Base runtime shell files and Base version helpers remain in
`basefoundry/base`. This repository carries only sourceable reusable library
modules.
