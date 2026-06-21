# `lib_str.sh`

String-oriented Bash helpers shared by CLI commands.

## Dependency

Source `lib/bash/std/lib_std.sh` before this library so logging and validation
helpers are available.

## Public API

- `str_lower`
  Print a string converted to lowercase.
- `str_upper`
  Print a string converted to uppercase.
- `str_trim`
  Print a string with leading and trailing whitespace removed.
- `str_ltrim`
  Print a string with leading whitespace removed.
- `str_rtrim`
  Print a string with trailing whitespace removed.
- `str_contains`
  Return success when a string contains a substring.
- `str_starts_with`
  Return success when a string starts with a prefix.
- `str_ends_with`
  Return success when a string ends with a suffix.
- `str_split`
  Split a string by a delimiter into a caller-provided array variable.
- `str_join`
  Join a caller-provided array variable into a caller-provided result variable.
- `str_in_array`
  Return success when a named array contains an exact string value.

## Usage

```bash
source "/absolute/path/to/lib/bash/std/lib_std.sh"
source "/absolute/path/to/lib/bash/str/lib_str.sh"

name="$(str_trim "  Example Project  ")"
slug="$(str_lower "$name")"

if str_starts_with "$slug" "example"; then
    log_info "Example project detected."
fi

parts=()
str_split parts "alpha,beta,,gamma" ","

joined=""
str_join joined "|" parts
```

## Behavior Notes

- Case conversion uses Bash's native `${value,,}` and `${value^^}` expansions.
- Trim helpers remove Bash character-class whitespace from the requested side.
- Predicate helpers return shell status and do not print output.
- `str_split` preserves empty fields between repeated delimiters.
- `str_join` preserves empty array elements, including trailing empty elements.
- Named result and array arguments must be valid Bash variable names.

## Tests

BATS coverage lives in `tests/lib_str.bats`.
