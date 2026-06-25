# `lib_arg.sh`

Argument and option parsing helpers for Base-style Bash scripts.

## Dependency

Source `lib/bash/std/lib_std.sh` before this library so validation and logging
helpers are available.

## Public API

- `arg_parse`
  Parse exact flag and value options into caller-owned arrays.

## Usage

```bash
source "/absolute/path/to/lib/bash/std/lib_std.sh"
source "/absolute/path/to/lib/bash/arg/lib_arg.sh"

declare -A options=()
declare -a positionals=()
specs=(
  "verbose|flag|--verbose|-v"
  "output|value|--output|-o"
)

arg_parse options positionals specs -- "$@" || exit $?

if [[ "${options[verbose]-}" == "1" ]]; then
    set_log_level DEBUG
fi
```

Spec entries use `name|kind|token[|token...]`:

- `name` is the associative-array key populated in the options result.
- `kind` is either `flag` or `value`.
- each `token` is an exact option token, such as `--verbose` or `-v`.

The parser supports `--option value`, `--option=value`, repeated options where
the last value wins, and `--` to stop option parsing. A value option followed by
another registered option token is treated as missing its value; use
`--option=value` when a value is intentionally option-like. Unknown options,
malformed specs, and missing values return status `2`.

## Tests

BATS coverage lives in `tests/lib_arg.bats`.
