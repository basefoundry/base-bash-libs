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

@test "validate detaches BATS from an interactive stdin" {
    local shim_dir="$TEST_TMPDIR/shim"
    local sentinel="$TEST_TMPDIR/bats-stdin"
    local pty_runner="$TEST_TMPDIR/run-in-pty.py"

    mkdir -p "$shim_dir"
    cat > "$shim_dir/shellcheck" <<'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
    cat > "$shim_dir/bats" <<'SCRIPT'
#!/usr/bin/env bash
if [[ -t 0 ]]; then
    printf 'tty\n' > "${VALIDATE_BATS_STDIN:?}"
else
    printf 'non-tty\n' > "${VALIDATE_BATS_STDIN:?}"
fi
exit 42
SCRIPT
    cat > "$pty_runner" <<'PYTHON'
#!/usr/bin/env python3
import os
import pty
import sys

wait_status = pty.spawn(sys.argv[1:])
sys.exit(os.waitstatus_to_exitcode(wait_status))
PYTHON
    chmod +x "$shim_dir/shellcheck" "$shim_dir/bats" "$pty_runner"

    run env PATH="$shim_dir:$PATH" VALIDATE_BATS_STDIN="$sentinel" \
        "$pty_runner" "$BASE_REPO_ROOT/tests/validate.sh"

    [ "$status" -eq 42 ]
    [ "$(cat "$sentinel")" = "non-tty" ]
}

@test "empty Unreleased is allowed for an untagged release-preparation section" {
    local candidate_repo="$TEST_TMPDIR/candidate-repo"

    mkdir -p "$candidate_repo"
    git -C "$candidate_repo" init -q
    git -C "$candidate_repo" config user.name "Validation test"
    git -C "$candidate_repo" config user.email "validation@example.invalid"
    printf '## [Unreleased]\n\nNo unreleased changes yet.\n' > "$candidate_repo/CHANGELOG.md"
    git -C "$candidate_repo" add CHANGELOG.md
    git -C "$candidate_repo" commit -qm "baseline"
    git -C "$candidate_repo" tag v2.1.0
    printf '2.2.0\n' > "$candidate_repo/VERSION"
    printf '## [Unreleased]\n\nNo unreleased changes yet.\n\n## [2.2.0] - 2026-10-05\n\n### Added\n\n- Candidate notes.\n' > "$candidate_repo/CHANGELOG.md"
    git -C "$candidate_repo" add VERSION CHANGELOG.md
    git -C "$candidate_repo" commit -qm "prepare 2.2.0"

    run bash -c 'source "$1"; check_changelog_unreleased_placeholder "$2" "$3"' \
        bash "$BASE_REPO_ROOT/tests/changelog-guard.sh" "$candidate_repo" 2.2.0

    [ "$status" -eq 0 ]
}

@test "empty Unreleased is rejected after a published release" {
    local candidate_repo="$TEST_TMPDIR/candidate-repo"

    mkdir -p "$candidate_repo"
    git -C "$candidate_repo" init -q
    git -C "$candidate_repo" config user.name "Validation test"
    git -C "$candidate_repo" config user.email "validation@example.invalid"
    printf '## [Unreleased]\n\nNo unreleased changes yet.\n' > "$candidate_repo/CHANGELOG.md"
    git -C "$candidate_repo" add CHANGELOG.md
    git -C "$candidate_repo" commit -qm "baseline"
    git -C "$candidate_repo" tag v2.1.0
    printf 'post-release change\n' > "$candidate_repo/marker"
    git -C "$candidate_repo" add marker
    git -C "$candidate_repo" commit -qm "post-release change"

    run bash -c 'source "$1"; check_changelog_unreleased_placeholder "$2" "$3"' \
        bash "$BASE_REPO_ROOT/tests/changelog-guard.sh" "$candidate_repo" 2.1.0

    [ "$status" -eq 1 ]
    [[ "$output" == *"cannot retain the empty Unreleased placeholder"* ]]
}
