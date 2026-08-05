# `lib_str.sh`

String-oriented Bash helpers shared by CLI commands.

## Dependency

Source `lib/bash/std/lib_std.sh` before this library so logging and validation
helpers are available.

## Public API

- `bl_str_lower <result_var>`
  Convert a named variable's value to lowercase in place.
- `bl_str_upper <result_var>`
  Convert a named variable's value to uppercase in place.
- `bl_str_trim <result_var>`
  Remove leading and trailing whitespace from a named variable in place.
- `bl_str_ltrim <result_var>`
  Remove leading whitespace from a named variable in place.
- `bl_str_rtrim <result_var>`
  Remove trailing whitespace from a named variable in place.
- `bl_str_contains <value> <substring>`
  Return success when a string contains a substring.
- `bl_str_starts_with <value> <prefix>`
  Return success when a string starts with a prefix.
- `bl_str_ends_with <value> <suffix>`
  Return success when a string ends with a suffix.
- `bl_str_split <result_array> <value> <separator>`
  Split a string by a delimiter into a caller-provided array variable.
- `bl_str_join <result_var> <separator> <source_array>`
  Join a caller-provided array variable into a caller-provided result variable.

## Usage

```bash
source "/absolute/path/to/lib/bash/std/lib_std.sh"
declare -a app_args=()
bl_init app_args --source "${BASH_SOURCE[0]}" --
source "/absolute/path/to/lib/bash/str/lib_str.sh"

name="  Example Project  "
bl_str_trim name
bl_str_lower name

if bl_str_starts_with "$name" "example"; then
    bl_std_log_info "Example project detected."
fi

parts=()
bl_str_split parts "alpha,beta,,gamma" ","

joined=""
bl_str_join joined "|" parts
```

## Behavior Notes

- Case conversion uses Bash's native `${value,,}` and `${value^^}` expansions.
- Trim helpers remove Bash character-class whitespace from the requested side.
- String transformation helpers mutate the named variable in place and do not
  print transformed values for command substitution.
- Predicate helpers require exactly two arguments, return shell status, and do
  not print output.
- `bl_str_split` preserves empty fields between repeated delimiters.
- `bl_str_split` preserves a trailing empty field when the input ends with the
  separator.
- `bl_str_join` preserves empty array elements, including trailing empty elements.
- `bl_str_join` requires distinct result and source variable names and rejects an
  alias before changing caller state.
- Use `bl_list_contains` from `lib/bash/list/lib_list.sh` for indexed-array
  membership checks.
- Named string, result, and array arguments must be valid Bash variable names.
- Array arguments and array result variables must already be declared as indexed
  arrays, for example with `declare -a parts=()`.

## Tests

BATS coverage lives in `lib/bash/str/tests/lib_str.bats`.
