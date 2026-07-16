# `lib_file.sh`

File-oriented Bash helpers shared by CLI commands.

## Dependency

Source `lib/bash/std/lib_std.sh` before this library so logging and error helpers are available.

## Public API

- `file_section_exists`
  Inspect whether a valid marker-delimited block is present without changing
  the file.
- `file_section_needs_update`
  Inspect whether adding or replacing a marker-delimited block would change the
  file.
- `update_file_section`
  Idempotently add, replace, or remove a marker-delimited block inside a file.

## Usage

```bash
source "/absolute/path/to/lib/bash/std/lib_std.sh"
source "/absolute/path/to/lib/bash/file/lib_file.sh"

update_file_section ~/.bash_profile "# BEGIN APP" "# END APP" \
    "export APP_HOME=/opt/app" \
    "alias appctl='app status'"
```

Use the inspection helpers before dry-run output, backup creation, or other
caller-owned side effects:

```bash
if file_section_needs_update ~/.bash_profile "# BEGIN APP" "# END APP" \
    "export APP_HOME=/opt/app"; then
    cp -p ~/.bash_profile ~/.bash_profile.backup
    update_file_section ~/.bash_profile "# BEGIN APP" "# END APP" \
        "export APP_HOME=/opt/app"
fi
```

## Behavior Notes

- Returns success when the target file does not exist and there is nothing to remove.
- Replaces or removes only the first matching marked section when markers already exist.
- Treats markers as exact full lines; marker text embedded in longer lines is ignored.
- Requires non-empty, distinct, single-line marker values.
- Preserves a target symlink while atomically updating its referent.
- Treats option-like target paths literally.
- Appends the marked block when markers are not present.
- `file_section_exists` returns `0` when a valid marker pair is present, `1`
  when the target file is missing or the section is absent, and `2` when marker
  pairs are asymmetric or misordered.
- `file_section_needs_update` returns `0` when an add/update would change the
  target file, `1` when the first existing marked section already matches, and
  `2` when marker pairs are asymmetric or misordered.

## Tests

BATS coverage lives in `lib/bash/file/tests/lib_file.bats`.
