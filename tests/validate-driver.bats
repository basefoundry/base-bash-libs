#!/usr/bin/env bats

load ../lib/bash/tests/test_helper.sh

setup() {
    setup_test_tmpdir
}

@test "validate stops before BATS when ShellCheck fails" {
    local shim_dir="$TEST_TMPDIR/shim"
    local sentinel="$TEST_TMPDIR/reached-bats"

    mkdir -p "$shim_dir"
    cat > "$shim_dir/shellcheck" <<'SCRIPT'
#!/usr/bin/env bash
exit 42
SCRIPT
    cat > "$shim_dir/bats" <<'SCRIPT'
#!/usr/bin/env bash
printf 'reached\n' > "${VALIDATE_BATS_SENTINEL:?}"
exit 99
SCRIPT
    chmod +x "$shim_dir/shellcheck" "$shim_dir/bats"

    run env PATH="$shim_dir:$PATH" VALIDATE_BATS_SENTINEL="$sentinel" \
        "$BASE_REPO_ROOT/tests/validate.sh"

    [ "$status" -eq 42 ]
    [[ "$output" == *"Validation stage failed: ShellCheck error profile (exit 42)."* ]]
    [ ! -e "$sentinel" ]
}
