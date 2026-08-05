# Bash Libraries

Reusable Bash libraries for command wrappers and other Bash tooling.

## Layout

- `std/`
  Foundation library with logging, error handling, PATH helpers, and other
  shared Bash primitives.
- `git/`
  Git-related helpers built on top of the stdlib.
- `gh/`
  GitHub CLI helpers built on top of the stdlib.
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

## Caller Runtime Contract

All public modules support Bash 4.2 or newer with every combination of caller-
selected `errexit`, `nounset`, and `pipefail`. Sourcing a module is passive: it
does not change those settings, any other `set` or `shopt` option, `IFS`,
`OPTIND`, the working directory, the umask, traps, exports, or ordinary
positional arguments. After sourcing `lib_std.sh`, callers explicitly invoke
`base_bash_libs_init` to initialize runtime state and receive wrapper-filtered
arguments in a caller-owned array.

Public API calls preserve the same process state unless their documented
purpose is to change it. Examples of intentional mutation include PATH helpers,
`base_bash_libs_std_safe_cd`, caller-owned output variables, file-editing helpers, and cleanup
registrations while a hook or path remains active. Transient internal cleanup
registrations restore the caller's preexisting `EXIT` trap when the operation
finishes.

Required arity is checked before a public helper expands a required positional
parameter, so a usage error remains diagnosable with caller `nounset` enabled.
Predicates and recoverable failures intentionally return nonzero; callers using
`errexit` should invoke expected nonzero results in `if`, `while`, `&&`, or
another Bash conditional context.

The standalone `tests/bash-option-contract.sh` matrix sources every module and
exercises success, usage, predicate, and recoverable-failure paths in all eight
option combinations. CI runs that matrix on the current macOS and Ubuntu Bash
runtimes and in the digest-pinned, networkless Bash 4.2.53 compatibility image.

## Naming Contract

The v2 namespace is part of the sourceable-library contract:

- Public functions use `base_bash_libs_<module>_<name>`. The stdlib lifecycle
  functions are `base_bash_libs_init` and `base_bash_libs_require_version`,
  while the remaining stdlib functions use the `base_bash_libs_std_` segment.
- Framework-owned globals, configuration variables, metadata, and load guards
  use `BASE_BASH_LIBS_...`.
- Implementation-only functions use `__base_bash_libs_<module>_...__` and are
  not a supported call surface.

Libraries do not define generic aliases for the old v1 names. This keeps
default loading safe for applications that already have functions such as
`import`, `log_info`, or `str_trim`. See
[`docs/v2-symbol-map.md`](../../docs/v2-symbol-map.md) for the complete mapping
and [`scripts/migrate-v2-symbols`](../../scripts/migrate-v2-symbols) for a
mechanical migration aid. The single-file boundary remains unchanged: each
public library is still one physical `.sh` file.

Public helpers that accept caller-supplied variable or array names reserve the
`__` prefix for library-internal state. Passing a caller-owned source or result
name that begins with `__` fails before the helper changes caller state. Use a
regular Bash variable name for public input and output values and arrays.
`base_bash_libs_std_assert_variable_name` is the syntax-only exception: it validates whether any
identifier is legal Bash syntax, including names in the reserved namespace,
without reading or writing the named variable.

When one API accepts multiple caller-owned inputs or outputs, names that would
alias an input with an output are rejected before mutation. The module README
for that API documents the required distinct-name relationships.
