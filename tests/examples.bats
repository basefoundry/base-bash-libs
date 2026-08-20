#!/usr/bin/env bats

load ../lib/bash/tests/test_helper.sh

setup() {
    setup_test_tmpdir
}

@test "std usage example does not follow a predictable temp-file symlink" {
    local wrapper="$TEST_TMPDIR/run-std-usage.sh"
    local target="$TEST_TMPDIR/protected-target"
    local temp_root="$TEST_TMPDIR/temp-root"
    local predictable_prefix="$temp_root/base-bash-libs-example."
    local predictable_path_file="$TEST_TMPDIR/predictable-path"
    local predictable_path
    local created_path

    mkdir -p "$temp_root"
    cat > "$wrapper" <<EOF
#!/usr/bin/env bash
target="$target"
predictable_path="$predictable_prefix\$\$"
printf 'original\\n' > "\$target"
ln -s "\$target" "\$predictable_path"
printf '%s\\n' "\$predictable_path" > "$predictable_path_file"
TMPDIR="$temp_root" exec "$BASE_REPO_ROOT/examples/std-usage.sh"
EOF
    chmod +x "$wrapper"

    bats_run bash "$wrapper"

    [ "$status" -eq 0 ]
    [ "$(<"$target")" = original ]
    predictable_path="$(<"$predictable_path_file")"
    [ -L "$predictable_path" ]
    created_path="$(printf '%s\n' "$output" | sed -n 's/^example_file=//p')"
    [ -n "$created_path" ]
    [ ! -e "$created_path" ]
}
