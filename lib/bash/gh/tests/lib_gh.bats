#!/usr/bin/env bats

load ../../tests/test_helper.sh

setup() {
    setup_test_tmpdir
    export TEST_TMPDIR
    mkdir -p "$TEST_TMPDIR/bin"
    PATH="$TEST_TMPDIR/bin:$BASE_TEST_ORIG_PATH"
    source "$BASE_BASH_DIR/std/lib_std.sh"
    source "$BASE_BASH_DIR/gh/lib_gh.sh"
}

create_fake_gh() {
    local script="$TEST_TMPDIR/bin/gh"

    cat > "$script"
    chmod +x "$script"
}

create_fake_git() {
    local script="$TEST_TMPDIR/bin/git"

    cat > "$script"
    chmod +x "$script"
}

@test "lib_gh can be sourced more than once" {
    source "$BASE_BASH_DIR/gh/lib_gh.sh"

    [ "$(type -t gh_run)" = "function" ]
}

@test "lib_gh fails clearly when sourced without stdlib" {
    bats_run bash -c 'source "$1"; rc=$?; printf "source-rc=%s\n" "$rc"; exit "$rc"' bash "$BASE_BASH_DIR/gh/lib_gh.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"lib_gh.sh requires lib_std.sh to be sourced first"* ]]
    [[ "$output" == *"source-rc=1"* ]]
    [[ "$output" != *"command not found"* ]]
}

@test "gh_require_cli succeeds when gh is on PATH" {
    create_fake_gh <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

    capture_command gh_require_cli

    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "gh_require_cli reports missing gh with caller hint" {
    mkdir -p "$TEST_TMPDIR/no-gh-bin"

    bats_run "$BASH" -c '
        source "$1"
        source "$2"
        PATH="$3"
        gh_require_cli "$4"
    ' bash "$BASE_BASH_DIR/std/lib_std.sh" "$BASE_BASH_DIR/gh/lib_gh.sh" "$TEST_TMPDIR/no-gh-bin" "Install GitHub CLI and retry."

    [ "$status" -eq 1 ]
    [[ "$output" == *"Required command 'gh' was not found on PATH."* ]]
    [[ "$output" == *"Install GitHub CLI and retry."* ]]
}

@test "gh_auth_status_diagnostics reports bounded auth output and hint" {
    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" && "$2" == "status" ]]; then
    printf 'auth failed\n' >&2
    printf 'run login\n' >&2
    exit 4
fi
exit 0
EOF

    capture_command gh_auth_status_diagnostics "Run a custom login command."

    [ "$status" -eq 1 ]
    [[ "$output" == *"gh auth status: auth failed"* ]]
    [[ "$output" == *"gh auth status: run login"* ]]
    [[ "$output" == *"Run a custom login command."* ]]
}

@test "gh_run passes through successful gh output" {
    create_fake_gh <<'EOF'
#!/usr/bin/env bash
printf 'gh args:'
printf ' <%s>' "$@"
printf '\n'
EOF

    capture_command gh_run issue list --repo owner/repo

    [ "$status" -eq 0 ]
    [[ "$output" == *"gh args: <issue> <list> <--repo> <owner/repo>"* ]]
}

@test "gh_run reports command failure and auth diagnostics" {
    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" && "$2" == "status" ]]; then
    printf 'not logged in\n' >&2
    exit 1
fi
printf 'command failed\n' >&2
exit 7
EOF

    capture_command gh_run issue create --title Example

    [ "$status" -eq 7 ]
    [[ "$output" == *"command failed"* ]]
    [[ "$output" == *"GitHub command failed: gh issue create --title Example"* ]]
    [[ "$output" == *"gh auth status: not logged in"* ]]
    [[ "$output" == *"Run 'gh auth login -h github.com' and retry."* ]]
}

@test "gh_run reports command failure under set -e" {
    local script="$TEST_TMPDIR/gh-run-set-e.sh"

    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" && "$2" == "status" ]]; then
    printf 'not logged in\n' >&2
    exit 1
fi
printf 'command failed\n' >&2
exit 7
EOF
    cat > "$script" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "$BASE_BASH_DIR/std/lib_std.sh"
source "$BASE_BASH_DIR/gh/lib_gh.sh"
PATH="$TEST_TMPDIR/bin:$BASE_TEST_ORIG_PATH"
gh_run issue create --title Example
printf 'after\n'
EOF
    chmod +x "$script"

    bats_run bash "$script"

    [ "$status" -eq 7 ]
    [[ "$output" == *"command failed"* ]]
    [[ "$output" == *"GitHub command failed: gh issue create --title Example"* ]]
    [[ "$output" == *"gh auth status: not logged in"* ]]
    [[ "$output" != *"after"* ]]
}

@test "gh_run quotes arguments when reporting command failure" {
    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" && "$2" == "status" ]]; then
    exit 0
fi
exit 7
EOF

    bats_run gh_run issue create --title "Example Title" --body "body value"

    [ "$status" -eq 7 ]
    [[ "$output" == *"GitHub command failed: gh issue create --title Example\\ Title --body body\\ value"* ]]
    [[ "$output" != *"GitHub command failed: gh issue create --title Example Title --body body value"* ]]
}

@test "gh_run returns 1 with an error when gh is not on PATH" {
    mkdir -p "$TEST_TMPDIR/no-gh-bin"

    bats_run "$BASH" -c '
        source "$1"
        source "$2"
        PATH="$3"
        gh_run issue list
    ' bash "$BASE_BASH_DIR/std/lib_std.sh" "$BASE_BASH_DIR/gh/lib_gh.sh" "$TEST_TMPDIR/no-gh-bin"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Required command 'gh' was not found on PATH."* ]]
    [[ "$output" != *"GitHub command failed"* ]]
    [[ "$output" != *"gh auth status"* ]]
}

@test "gh_repo_from_remote_url parses supported GitHub remotes" {
    local repo

    gh_repo_from_remote_url "git@github.com:owner/repo.git" repo
    [ "$repo" = "owner/repo" ]

    gh_repo_from_remote_url "git@github.com:owner/repo" repo
    [ "$repo" = "owner/repo" ]

    gh_repo_from_remote_url "https://github.com/owner/repo.git" repo
    [ "$repo" = "owner/repo" ]

    gh_repo_from_remote_url "https://github.com/owner/repo" repo
    [ "$repo" = "owner/repo" ]
}

@test "gh_repo_from_remote_url supports shadowing-prone output variable names" {
    local result_var=""
    local parsed_repo=""

    gh_repo_from_remote_url "https://github.com/owner/repo.git" result_var
    gh_repo_from_remote_url "git@github.com:other/project.git" parsed_repo

    [ "$result_var" = "owner/repo" ]
    [ "$parsed_repo" = "other/project" ]
}

@test "gh_repo_from_remote_url rejects non-GitHub and malformed remotes" {
    local repo="sentinel"

    bats_run gh_repo_from_remote_url "https://example.com/owner/repo.git" repo

    [ "$status" -eq 1 ]
    [ "$repo" = "sentinel" ]

    bats_run gh_repo_from_remote_url "https://github.com/owner" repo

    [ "$status" -eq 1 ]
    [ "$repo" = "sentinel" ]
}

@test "gh_infer_repo_from_origin reads origin through git -C" {
    local repo_dir="$TEST_TMPDIR/repo"
    local repo=""

    init_git_repo "$repo_dir"
    git -C "$repo_dir" remote add origin "git@github.com:owner/repo.git"

    gh_infer_repo_from_origin "$repo_dir" repo

    [ "$repo" = "owner/repo" ]
}

@test "gh_infer_repo_from_origin supports inferred_repo as the result variable name" {
    local repo_dir="$TEST_TMPDIR/repo"
    local inferred_repo=""

    init_git_repo "$repo_dir"
    git -C "$repo_dir" remote add origin "git@github.com:owner/repo.git"

    gh_infer_repo_from_origin "$repo_dir" inferred_repo

    [ "$inferred_repo" = "owner/repo" ]
}

@test "gh_infer_repo_from_origin supports remote_url as the result variable name" {
    local repo_dir="$TEST_TMPDIR/repo"
    local remote_url=""

    init_git_repo "$repo_dir"
    git -C "$repo_dir" remote add origin "git@github.com:owner/repo.git"

    gh_infer_repo_from_origin "$repo_dir" remote_url

    [ "$remote_url" = "owner/repo" ]
}

@test "gh_infer_repo_from_origin returns empty success for non-GitHub remotes when optional" {
    local repo_dir="$TEST_TMPDIR/repo"
    local repo="sentinel"

    init_git_repo "$repo_dir"
    git -C "$repo_dir" remote add origin "https://example.com/owner/repo.git"

    gh_infer_repo_from_origin "$repo_dir" repo --optional

    [ "$repo" = "" ]
}

@test "gh_infer_repo_from_origin logs non-optional inference failures" {
    local repo_dir="$TEST_TMPDIR/repo"
    local repo="sentinel"

    init_git_repo "$repo_dir"
    git -C "$repo_dir" remote add origin "https://example.com/owner/repo.git"

    bats_run gh_infer_repo_from_origin "$repo_dir" repo

    [ "$status" -eq 1 ]
    [ "$repo" = "sentinel" ]
    [[ "$output" == *"Could not infer GitHub repository from '$repo_dir' origin remote."* ]]
}

@test "gh_detect_default_branch prefers origin HEAD and falls back to local main or master" {
    local repo_dir="$TEST_TMPDIR/repo"
    local branch=""

    init_git_repo "$repo_dir"
    printf 'base\n' > "$repo_dir/data.txt"
    commit_all "$repo_dir" "Initial commit"
    git -C "$repo_dir" update-ref refs/remotes/origin/trunk HEAD
    git -C "$repo_dir" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk

    gh_detect_default_branch "$repo_dir" branch

    [ "$branch" = "trunk" ]

    git -C "$repo_dir" symbolic-ref -d refs/remotes/origin/HEAD
    gh_detect_default_branch "$repo_dir" branch

    [ "$branch" = "main" ]
}

@test "gh_detect_default_branch supports default_branch as the result variable name" {
    local repo_dir="$TEST_TMPDIR/repo"
    local default_branch=""

    init_git_repo "$repo_dir"
    printf 'base\n' > "$repo_dir/data.txt"
    commit_all "$repo_dir" "Initial commit"

    gh_detect_default_branch "$repo_dir" default_branch

    [ "$default_branch" = "main" ]
}

@test "gh_detect_default_branch supports detected_branch as the result variable name" {
    local repo_dir="$TEST_TMPDIR/repo"
    local detected_branch=""

    init_git_repo "$repo_dir"
    printf 'base\n' > "$repo_dir/data.txt"
    commit_all "$repo_dir" "Initial commit"

    gh_detect_default_branch "$repo_dir" detected_branch

    [ "$detected_branch" = "main" ]
}

@test "gh_detect_default_branch reports failure when no default branch can be detected" {
    local repo_dir="$TEST_TMPDIR/repo"
    local branch="sentinel"

    init_git_repo "$repo_dir" feature
    printf 'base\n' > "$repo_dir/data.txt"
    commit_all "$repo_dir" "Initial commit"

    bats_run gh_detect_default_branch "$repo_dir" branch

    [ "$status" -eq 1 ]
    [ "$branch" = "sentinel" ]
}

@test "gh_repo_default_branch reads GitHub repository default branch" {
    local branch=""

    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "repo" && "$2" == "view" ]]; then
    printf 'develop\n'
    exit 0
fi
exit 99
EOF

    gh_repo_default_branch "owner/repo" branch

    [ "$branch" = "develop" ]
}

@test "gh_repo_default_branch supports default_branch as the result variable name" {
    local default_branch=""

    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "repo" && "$2" == "view" ]]; then
    printf 'develop\n'
    exit 0
fi
exit 99
EOF

    gh_repo_default_branch "owner/repo" default_branch

    [ "$default_branch" = "develop" ]
}

@test "gh_repo_default_branch supports remote_default_branch as the result variable name" {
    local remote_default_branch=""

    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "repo" && "$2" == "view" ]]; then
    printf 'develop\n'
    exit 0
fi
exit 99
EOF

    gh_repo_default_branch "owner/repo" remote_default_branch

    [ "$remote_default_branch" = "develop" ]
}

@test "gh_repo_default_branch supports status as the result variable name" {
    local status=""

    create_fake_gh <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "repo" && "$2" == "view" ]]; then
    printf 'develop\n'
    exit 0
fi
exit 99
EOF

    gh_repo_default_branch "owner/repo" status

    [ "$status" = "develop" ]
}

@test "gh_api_with_retry retries retryable API pressure once" {
    create_fake_gh <<'EOF'
#!/usr/bin/env bash
state_file="${TEST_TMPDIR:?}/gh-api-count"
count=0
[[ -f "$state_file" ]] && read -r count < "$state_file"
count=$((count + 1))
printf '%s\n' "$count" > "$state_file"
if ((count == 1)); then
    printf 'secondary rate limit; retry-after: 0\n' >&2
    exit 1
fi
printf 'ok\n'
EOF

    capture_command gh_api_with_retry repos/owner/repo --jq .name

    [ "$status" -eq 0 ]
    [[ "$output" == *"GitHub API call failed on attempt 1; retrying once."* ]]
    [[ "$output" == *"ok"* ]]
    [ "$(cat "$TEST_TMPDIR/gh-api-count")" = "2" ]
}

@test "gh_api_with_retry preserves non-retryable failures" {
    create_fake_gh <<'EOF'
#!/usr/bin/env bash
printf 'not found\n' >&2
exit 4
EOF

    capture_command gh_api_with_retry repos/owner/missing

    [ "$status" -eq 4 ]
    [[ "$output" == *"not found"* ]]
    [[ "$output" != *"retrying"* ]]
}

@test "gh_worktree_path_for_branch finds the worktree for a local branch" {
    create_fake_git <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "worktree" && "$2" == "list" ]]; then
    cat <<'OUT'
worktree /tmp/main
HEAD abc123
branch refs/heads/main

worktree /tmp/feature
HEAD def456
branch refs/heads/feature/test
OUT
    exit 0
fi
exit 99
EOF

    capture_command gh_worktree_path_for_branch feature/test

    [ "$status" -eq 0 ]
    [ "$output" = "/tmp/feature" ]
}

@test "gh_worktree_path_for_branch uses repo_dir when provided" {
    create_fake_git <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-C" && "$3" == "worktree" && "$4" == "list" ]]; then
    printf 'repo-dir=%s\n' "$2" > "${TEST_TMPDIR:?}/git-repo-dir"
    cat <<'OUT'
worktree /tmp/main
HEAD abc123
branch refs/heads/main

worktree /tmp/feature
HEAD def456
branch refs/heads/feature/test
OUT
    exit 0
fi
exit 99
EOF

    capture_command gh_worktree_path_for_branch feature/test "$TEST_TMPDIR/repo"

    [ "$status" -eq 0 ]
    [ "$output" = "/tmp/feature" ]
    [ "$(cat "$TEST_TMPDIR/git-repo-dir")" = "repo-dir=$TEST_TMPDIR/repo" ]
}

@test "gh_list_worktree_branches emits path and branch pairs" {
    create_fake_git <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "worktree" && "$2" == "list" ]]; then
    cat <<'OUT'
worktree /tmp/main
HEAD abc123
branch refs/heads/main

worktree /tmp/feature
HEAD def456
branch refs/heads/feature/test
OUT
    exit 0
fi
exit 99
EOF

    capture_command gh_list_worktree_branches

    [ "$status" -eq 0 ]
    [[ "$output" == *$'/tmp/main\tmain'* ]]
    [[ "$output" == *$'/tmp/feature\tfeature/test'* ]]
}

@test "gh_list_worktree_branches uses repo_dir when provided" {
    create_fake_git <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-C" && "$3" == "worktree" && "$4" == "list" ]]; then
    printf 'repo-dir=%s\n' "$2" > "${TEST_TMPDIR:?}/git-repo-dir"
    cat <<'OUT'
worktree /tmp/main
HEAD abc123
branch refs/heads/main

worktree /tmp/feature
HEAD def456
branch refs/heads/feature/test
OUT
    exit 0
fi
exit 99
EOF

    capture_command gh_list_worktree_branches "$TEST_TMPDIR/repo"

    [ "$status" -eq 0 ]
    [[ "$output" == *$'/tmp/main\tmain'* ]]
    [[ "$output" == *$'/tmp/feature\tfeature/test'* ]]
    [ "$(cat "$TEST_TMPDIR/git-repo-dir")" = "repo-dir=$TEST_TMPDIR/repo" ]
}

@test "gh_branch_upstream prints the configured upstream" {
    local repo_dir="$TEST_TMPDIR/repo"
    local remote_dir="$TEST_TMPDIR/remote.git"

    create_tracked_repo_with_upstream "$repo_dir" "$remote_dir" "data.txt" "base"

    capture_command gh_branch_upstream "$repo_dir" main

    [ "$status" -eq 0 ]
    [ "$output" = "origin/main" ]
}

@test "gh_branch_merged_to_ref succeeds only for ancestors" {
    local repo_dir="$TEST_TMPDIR/repo"

    init_git_repo "$repo_dir"
    printf 'base\n' > "$repo_dir/data.txt"
    commit_all "$repo_dir" "Initial commit"
    git -C "$repo_dir" branch feature
    printf 'main\n' > "$repo_dir/data.txt"
    commit_all "$repo_dir" "Main change"

    gh_branch_merged_to_ref "$repo_dir" feature main
}

@test "gh_branch_merged_to_ref fails for branches not merged to the ref" {
    local repo_dir="$TEST_TMPDIR/repo"

    init_git_repo "$repo_dir"
    printf 'base\n' > "$repo_dir/data.txt"
    commit_all "$repo_dir" "Initial commit"
    git -C "$repo_dir" switch -c feature >/dev/null 2>&1
    printf 'feature\n' > "$repo_dir/data.txt"
    commit_all "$repo_dir" "Feature change"
    git -C "$repo_dir" switch main >/dev/null 2>&1

    bats_run gh_branch_merged_to_ref "$repo_dir" feature main

    [ "$status" -eq 1 ]
}

@test "gh_list_remote_branches lists remote heads" {
    create_fake_git <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-C" ]]; then
    shift 2
fi
if [[ "$1" == "ls-remote" && "$2" == "--heads" && "$3" == "origin" ]]; then
    printf 'abc\trefs/heads/main\n'
    printf 'def\trefs/heads/feature/test\n'
    exit 0
fi
exit 99
EOF

    capture_command gh_list_remote_branches "$TEST_TMPDIR/repo"

    [ "$status" -eq 0 ]
    [[ "$output" == *"main"* ]]
    [[ "$output" == *"feature/test"* ]]
}

@test "gh_list_remote_branches keeps sha loop variable local" {
    local _sha="sentinel"

    create_fake_git <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-C" ]]; then
    shift 2
fi
if [[ "$1" == "ls-remote" && "$2" == "--heads" && "$3" == "origin" ]]; then
    printf 'abc\trefs/heads/main\n'
    printf 'def\trefs/heads/feature/test\n'
    exit 0
fi
exit 99
EOF

    capture_command gh_list_remote_branches "$TEST_TMPDIR/repo"

    [ "$status" -eq 0 ]
    [ "$_sha" = "sentinel" ]
}
