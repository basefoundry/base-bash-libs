# `lib_list.sh`

Indexed-array helpers for Base-style Bash scripts.

## Dependency

Source `lib/bash/std/lib_std.sh` before this library so validation and error
helpers are available.

## Public API

- `list_append`
  Append one or more values to a named indexed array.
- `list_prepend`
  Prepend one or more values to a named indexed array.
- `list_remove`
  Remove all exact matches from a named indexed array.
- `list_contains`
  Predicate that checks whether a named indexed array contains a value.
- `list_unique`
  Store first-seen unique values in a named result array.
- `list_length`
  Store an array length in a named result variable.

## Usage

```bash
source "/absolute/path/to/lib/bash/std/lib_std.sh"
source "/absolute/path/to/lib/bash/list/lib_list.sh"

declare -a packages=("jq")

list_append packages "shellcheck" "bats-core"
list_prepend packages "bash"

if list_contains "shellcheck" packages; then
    log_info "ShellCheck validation is available."
fi
```

Mutating helpers update the caller-owned array in place. Result helpers accept
the name of the output variable, validate it with `assert_variable_name`, and
avoid stdout capture for caller state.

## Tests

BATS coverage lives in `tests/lib_list.bats`.
