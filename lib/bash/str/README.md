# `lib_str.sh`

String-oriented Bash helpers shared by CLI commands.

## Dependency

Source `lib/bash/std/lib_std.sh` before this library so logging and validation
helpers are available.

## Public API

- `str_lower`
  Convert a named variable's value to lowercase in place.
- `str_upper`
  Convert a named variable's value to uppercase in place.
- `str_trim`
  Remove leading and trailing whitespace from a named variable in place.
- `str_ltrim`
  Remove leading whitespace from a named variable in place.
- `str_rtrim`
  Remove trailing whitespace from a named variable in place.
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

## Usage

```bash
source "/absolute/path/to/lib/bash/std/lib_std.sh"
source "/absolute/path/to/lib/bash/str/lib_str.sh"

name="  Example Project  "
str_trim name
str_lower name

if str_starts_with "$name" "example"; then
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
- String transformation helpers mutate the named variable in place and do not
  print transformed values for command substitution.
- Predicate helpers require exactly two arguments, return shell status, and do
  not print output.
- `str_split` preserves empty fields between repeated delimiters.
- `str_join` preserves empty array elements, including trailing empty elements.
- Use `list_contains` from `lib/bash/list/lib_list.sh` for indexed-array
  membership checks.
- Named string, result, and array arguments must be valid Bash variable names.
- Array arguments and array result variables must already be declared as indexed
  arrays, for example with `declare -a parts=()`.

## Tests

BATS coverage lives in `lib/bash/str/tests/lib_str.bats`.
