#!/usr/bin/env bats

load ../../tests/test_helper.sh

setup() {
    setup_test_tmpdir
    source "$BASE_BASH_DIR/std/lib_std.sh"
    source "$BASE_BASH_DIR/file/lib_file.sh"
}

file_inode() {
    if stat -c '%i' "$1" >/dev/null 2>&1; then
        stat -c '%i' "$1"
    else
        stat -f '%i' "$1"
    fi
}

file_mode() {
    if stat -c '%a' "$1" >/dev/null 2>&1; then
        stat -c '%a' "$1"
    else
        stat -f '%Lp' "$1"
    fi
}

@test "update_file_section appends a new marked block when markers are absent" {
    local target="$TEST_TMPDIR/config.txt"
    printf 'line-one' > "$target"

    update_file_section "$target" "# BEGIN" "# END" "first" "second"

    [ "$(cat "$target")" = $'line-one\n# BEGIN\nfirst\nsecond\n# END' ]
}

@test "update_file_section logs adding when markers are absent" {
    local script="$TEST_TMPDIR/add-log.sh"
    local target="$TEST_TMPDIR/config.txt"
    cat > "$script" <<EOF
#!/usr/bin/env bash
source "$BASE_BASH_DIR/std/lib_std.sh"
source "$BASE_BASH_DIR/file/lib_file.sh"
printf 'line-one' > "\$1"
update_file_section "\$1" "# BEGIN" "# END" "first"
EOF
    chmod +x "$script"

    bats_run bash "$script" "$target"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Adding section to '$target'"* ]]
    [[ "$output" != *"Updating '$target'"* ]]
    [ "$(cat "$target")" = $'line-one\n# BEGIN\nfirst\n# END' ]
}

@test "update_file_section appends to an empty file without a leading blank line" {
    local target="$TEST_TMPDIR/config.txt"
    touch "$target"

    update_file_section "$target" "# BEGIN" "# END" "first"

    [ "$(cat "$target")" = $'# BEGIN\nfirst\n# END' ]
}

@test "update_file_section preserves normal file mode when appending" {
    local target="$TEST_TMPDIR/config.txt"
    printf 'line-one' > "$target"
    chmod 0644 "$target"

    update_file_section "$target" "# BEGIN" "# END" "first"

    [ "$(file_mode "$target")" = "644" ]
    [ "$(cat "$target")" = $'line-one\n# BEGIN\nfirst\n# END' ]
}

@test "lib_file can be sourced more than once" {
    source "$BASE_BASH_DIR/file/lib_file.sh"

    [ "$(type -t update_file_section)" = "function" ]
}

@test "lib_file fails clearly when sourced without stdlib" {
    bats_run bash -c 'source "$1"; rc=$?; printf "source-rc=%s\n" "$rc"; exit "$rc"' bash "$BASE_BASH_DIR/file/lib_file.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"lib_file.sh requires lib_std.sh to be sourced first"* ]]
    [[ "$output" == *"source-rc=1"* ]]
    [[ "$output" != *"command not found"* ]]
}

@test "lib_file requires the stdlib loaded marker" {
    bats_run bash -c 'log_error() { :; }; log_debug() { :; }; source "$1"; rc=$?; printf "source-rc=%s\n" "$rc"; exit "$rc"' bash "$BASE_BASH_DIR/file/lib_file.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"lib_file.sh requires lib_std.sh to be sourced first"* ]]
    [[ "$output" == *"source-rc=1"* ]]
}

@test "update_file_section writes option-like markers literally" {
    local target="$TEST_TMPDIR/config.txt"
    printf 'line-one' > "$target"

    update_file_section "$target" "-n" "-e" "value"

    [ "$(cat "$target")" = $'line-one\n-n\nvalue\n-e' ]
}

@test "update_file_section preserves symlinks while updating their targets" {
    local target="$TEST_TMPDIR/config.txt"
    local link="$TEST_TMPDIR/config-link"
    printf 'before\n# BEGIN\nold\n# END\nafter\n' > "$target"
    ln -s "$(basename "$target")" "$link"

    update_file_section "$link" "# BEGIN" "# END" "new"

    [ -L "$link" ]
    [ "$(readlink "$link")" = "$(basename "$target")" ]
    [ "$(cat "$link")" = $'before\n# BEGIN\nnew\n# END\nafter' ]
}

@test "update_file_section treats option-like target paths literally" {
    local target="-config.txt"
    pushd "$TEST_TMPDIR" >/dev/null
    printf 'before' > "$target"

    update_file_section "$target" "# BEGIN" "# END" "new"

    [ "$(cat "./$target")" = $'before\n# BEGIN\nnew\n# END' ]
    popd >/dev/null
}

@test "update_file_section replaces the first matching section" {
    local target="$TEST_TMPDIR/config.txt"
    cat <<'EOF' > "$target"
before
# BEGIN
old
# END
after
EOF

    update_file_section "$target" "# BEGIN" "# END" "new"

    [ "$(cat "$target")" = $'before\n# BEGIN\nnew\n# END\nafter' ]
}

@test "update_file_section ignores marker substrings embedded in longer lines" {
    local target="$TEST_TMPDIR/config.txt"
    cat <<'EOF' > "$target"
before
echo # BEGIN
old
echo # END
after
EOF

    update_file_section "$target" "# BEGIN" "# END" "new"

    [ "$(cat "$target")" = $'before\necho # BEGIN\nold\necho # END\nafter\n# BEGIN\nnew\n# END' ]
}

@test "update_file_section preserves executable file mode when replacing" {
    local target="$TEST_TMPDIR/script.sh"
    cat <<'EOF' > "$target"
#!/usr/bin/env bash
# BEGIN
echo old
# END
EOF
    chmod 0755 "$target"

    update_file_section "$target" "# BEGIN" "# END" "echo new"

    [ -x "$target" ]
    [ "$(file_mode "$target")" = "755" ]
    [ "$(cat "$target")" = $'#!/usr/bin/env bash\n# BEGIN\necho new\n# END' ]
}

@test "update_file_section replaces an existing section with multi-line content" {
    local target="$TEST_TMPDIR/config.txt"
    cat <<'EOF' > "$target"
before
# BEGIN
old
# END
after
EOF

    update_file_section "$target" "# BEGIN" "# END" "first" "second" "third"

    [ "$(cat "$target")" = $'before\n# BEGIN\nfirst\nsecond\nthird\n# END\nafter' ]
}

@test "update_file_section registers internal temp files for cleanup" {
    local registration_file="$TEST_TMPDIR/registered-cleanup-paths.txt"
    local target="$TEST_TMPDIR/config.txt"
    cat <<'EOF' > "$target"
before
# BEGIN
old
# END
after
EOF

    eval "$(declare -f std_register_cleanup_path | sed '1s/std_register_cleanup_path/__orig_std_register_cleanup_path/')"
    std_register_cleanup_path() {
        printf '%s\n' "$@" >> "$registration_file"
        __orig_std_register_cleanup_path "$@"
    }

    update_file_section "$target" "# BEGIN" "# END" "new"
    unset -f std_register_cleanup_path __orig_std_register_cleanup_path

    [ "$(cat "$target")" = $'before\n# BEGIN\nnew\n# END\nafter' ]
    [[ "$(cat "$registration_file")" == *"base-file-section-new."* ]]
    [[ "$(cat "$registration_file")" == *"base-file-section-current."* ]]
    [[ "$(cat "$registration_file")" == *"config.txt."* ]]
}

@test "update_file_section unregisters temp files after eager cleanup" {
    local cleanup_path
    local target="$TEST_TMPDIR/config.txt"
    cat <<'EOF' > "$target"
before
# BEGIN
old
# END
after
EOF

    update_file_section "$target" "# BEGIN" "# END" "new"

    for cleanup_path in "${__std_cleanup_paths[@]}"; do
        if [[ "$cleanup_path" == *"base-file-section-new."* ||
            "$cleanup_path" == *"base-file-section-current."* ||
            "$cleanup_path" == *"config.txt."* ]]; then
            printf 'stale cleanup path: %s\n' "$cleanup_path" >&2
            return 1
        fi
    done
}

@test "update_file_section skips unchanged existing section" {
    local before_inode
    local target="$TEST_TMPDIR/config.txt"
    cat <<'EOF' > "$target"
before
# BEGIN
same
content
# END
after
EOF
    before_inode="$(file_inode "$target")"

    capture_command update_file_section "$target" "# BEGIN" "# END" "same" "content"

    [ "$status" -eq 0 ]
    [[ "$output" != *"Updating '$target'"* ]]
    [ "$(file_inode "$target")" = "$before_inode" ]
    [ "$(cat "$target")" = $'before\n# BEGIN\nsame\ncontent\n# END\nafter' ]

    set_log_level DEBUG
    capture_command update_file_section "$target" "# BEGIN" "# END" "same" "content"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Section already up to date in '$target'."* ]]
}

@test "file_section_exists detects a present marked section" {
    local target="$TEST_TMPDIR/config.txt"
    cat <<'EOF' > "$target"
before
# BEGIN
managed
# END
after
EOF

    capture_command file_section_exists "$target" "# BEGIN" "# END"

    [ "$status" -eq 0 ]
}

@test "file_section_exists returns no-change for absent and missing target files" {
    local target="$TEST_TMPDIR/config.txt"
    printf 'plain\ncontent\n' > "$target"

    capture_command file_section_exists "$target" "# BEGIN" "# END"
    [ "$status" -eq 1 ]

    capture_command file_section_exists "$TEST_TMPDIR/missing.txt" "# BEGIN" "# END"
    [ "$status" -eq 1 ]
}

@test "file-section helpers reject invalid marker contracts" {
    local target="$TEST_TMPDIR/config.txt"
    printf 'plain\ncontent\n' > "$target"

    capture_command file_section_exists "$target" "" "# END"
    [ "$status" -eq 2 ]

    capture_command file_section_needs_update "$target" "# BEGIN" "# BEGIN"
    [ "$status" -eq 2 ]

    capture_command update_file_section "$target" "# BEGIN" $'# END\nextra' "new"
    [ "$status" -eq 1 ]
    [ "$(cat "$target")" = $'plain\ncontent' ]
}

@test "file_section_exists rejects asymmetric markers" {
    local target="$TEST_TMPDIR/config.txt"
    cat <<'EOF' > "$target"
before
# BEGIN
orphaned
EOF

    bats_run file_section_exists "$target" "# BEGIN" "# END"

    [ "$status" -eq 2 ]
    [[ "$output" == *"Asymmetric markers in '$target': 1 start, 0 end. Manual repair needed."* ]]
}

@test "file_section_exists rejects misordered markers" {
    local target="$TEST_TMPDIR/config.txt"
    cat <<'EOF' > "$target"
before
# END
middle
# BEGIN
after
EOF

    bats_run file_section_exists "$target" "# BEGIN" "# END"

    [ "$status" -eq 2 ]
    [[ "$output" == *"Misordered markers in '$target'. Manual repair needed."* ]]
}

@test "file_section_needs_update detects changed marked section content" {
    local target="$TEST_TMPDIR/config.txt"
    cat <<'EOF' > "$target"
before
# BEGIN
old
# END
after
EOF

    capture_command file_section_needs_update "$target" "# BEGIN" "# END" "new"

    [ "$status" -eq 0 ]
}

@test "file_section_needs_update returns no-change for matching section content" {
    local target="$TEST_TMPDIR/config.txt"
    cat <<'EOF' > "$target"
before
# BEGIN
same
content
# END
after
EOF

    capture_command file_section_needs_update "$target" "# BEGIN" "# END" "same" "content"

    [ "$status" -eq 1 ]
}

@test "file_section_needs_update returns change-needed for absent and missing target files" {
    local target="$TEST_TMPDIR/config.txt"
    printf 'plain\ncontent\n' > "$target"

    capture_command file_section_needs_update "$target" "# BEGIN" "# END" "new"
    [ "$status" -eq 0 ]

    capture_command file_section_needs_update "$TEST_TMPDIR/missing.txt" "# BEGIN" "# END" "new"
    [ "$status" -eq 0 ]
}

@test "update_file_section does not export replacement content to awk" {
    local awk_log="$TEST_TMPDIR/awk-env.log"
    local target="$TEST_TMPDIR/config.txt"
    cat <<'EOF' > "$target"
before
# BEGIN
old
# END
after
EOF

    awk() {
        if [[ -n "${AWK_NEW_TEXT+x}" ]]; then
            printf 'leaked=%s\n' "$AWK_NEW_TEXT" > "$awk_log"
        else
            printf 'not-leaked\n' > "$awk_log"
        fi
        command awk "$@"
    }

    update_file_section "$target" "# BEGIN" "# END" "secret" "value"
    unset -f awk

    [ "$(cat "$awk_log")" = "not-leaked" ]
    [ "$(cat "$target")" = $'before\n# BEGIN\nsecret\nvalue\n# END\nafter' ]
}

@test "update_file_section removes a marked block with remove option" {
    local target="$TEST_TMPDIR/config.txt"
    cat <<'EOF' > "$target"
before
# BEGIN
remove-me
# END
after
EOF

    update_file_section -r "$target" "# BEGIN" "# END"

    [ "$(cat "$target")" = $'before\nafter' ]
}

@test "update_file_section removes only the first matching marked block with remove option" {
    local target="$TEST_TMPDIR/config.txt"
    cat <<'EOF' > "$target"
before
# BEGIN
remove-me
# END
middle
# BEGIN
keep-me
# END
after
EOF

    update_file_section -r "$target" "# BEGIN" "# END"

    [ "$(cat "$target")" = $'before\nmiddle\n# BEGIN\nkeep-me\n# END\nafter' ]
}

@test "update_file_section rejects a section with only a start marker" {
    local target="$TEST_TMPDIR/config.txt"
    cat <<'EOF' > "$target"
before
# BEGIN
orphaned
EOF

    bats_run update_file_section "$target" "# BEGIN" "# END" "new"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Asymmetric markers in '$target': 1 start, 0 end. Manual repair needed."* ]]
    [ "$(cat "$target")" = $'before\n# BEGIN\norphaned' ]
}

@test "update_file_section rejects a section with only an end marker" {
    local target="$TEST_TMPDIR/config.txt"
    cat <<'EOF' > "$target"
before
orphaned
# END
EOF

    bats_run update_file_section "$target" "# BEGIN" "# END" "new"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Asymmetric markers in '$target': 0 start, 1 end. Manual repair needed."* ]]
    [ "$(cat "$target")" = $'before\norphaned\n# END' ]
}

@test "update_file_section rejects end markers before start markers" {
    local before
    local target="$TEST_TMPDIR/config.txt"
    cat <<'EOF' > "$target"
before
# END
middle
# BEGIN
after
EOF
    before="$(cat "$target")"

    bats_run update_file_section "$target" "# BEGIN" "# END" "new"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Misordered markers in '$target'. Manual repair needed."* ]]
    [ "$(cat "$target")" = "$before" ]
}

@test "update_file_section is a no-op for a missing target file" {
    local target="$TEST_TMPDIR/missing.txt"

    capture_command update_file_section "$target" "# BEGIN" "# END" "value"

    [ "$status" -eq 0 ]
    [ ! -e "$target" ]
}

@test "update_file_section rejects content arguments when removing a section" {
    local target="$TEST_TMPDIR/config.txt"
    touch "$target"

    bats_run update_file_section -r "$target" "# BEGIN" "# END" "unexpected"

    [ "$status" -eq 1 ]
    [[ "$output" == *"When -r flag is used"* ]]
}

@test "update_file_section cleans up temp file when initial copy fails" {
    local target="$TEST_TMPDIR/config.txt"
    printf 'line-one' > "$target"

    cp() {
        : > "$2"
        return 1
    }

    capture_command update_file_section "$target" "# BEGIN" "# END" "value"
    unset -f cp

    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to copy"* ]]
    [ "$(cat "$target")" = "line-one" ]
    ! compgen -G "$target".'*' >/dev/null
}
