#!/usr/bin/env bats

load ../../tests/test_helper.sh

setup() {
    setup_test_tmpdir
    source "$BASE_BASH_DIR/std/lib_std.sh"
    source "$BASE_BASH_DIR/git/lib_git.sh"
}

@test "lib_git can be sourced more than once" {
    source "$BASE_BASH_DIR/git/lib_git.sh"

    [ "$(type -t git_update_repo)" = "function" ]
}

@test "lib_git fails clearly when sourced without stdlib" {
    bats_run bash -c 'source "$1"; rc=$?; printf "source-rc=%s\n" "$rc"; exit "$rc"' bash "$BASE_BASH_DIR/git/lib_git.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"lib_git.sh requires lib_std.sh to be sourced first"* ]]
    [[ "$output" == *"source-rc=1"* ]]
    [[ "$output" != *"command not found"* ]]
}

@test "lib_git requires the stdlib loaded marker" {
    bats_run bash -c 'log_error() { :; }; log_debug() { :; }; source "$1"; rc=$?; printf "source-rc=%s\n" "$rc"; exit "$rc"' bash "$BASE_BASH_DIR/git/lib_git.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"lib_git.sh requires lib_std.sh to be sourced first"* ]]
    [[ "$output" == *"source-rc=1"* ]]
}

@test "git_get_current_branch returns the current branch name" {
    local repo="$TEST_TMPDIR/repo"
    local branch=""

    init_git_repo "$repo"
    git_get_current_branch "$repo" branch

    [ "$branch" = "main" ]
}

@test "git_get_current_branch reports detached head" {
    local repo="$TEST_TMPDIR/repo"
    local branch=""

    init_git_repo "$repo"
    printf 'hello\n' > "$repo/README.md"
    commit_all "$repo" "Initial commit"
    git -C "$repo" checkout --detach >/dev/null 2>&1

    git_get_current_branch "$repo" branch

    [ "$branch" = "detached head" ]
}

@test "git_get_current_branch leaves missing directories as empty success" {
    local branch="sentinel"
    local rc

    if git_get_current_branch "$TEST_TMPDIR/missing" branch; then
        rc=0
    else
        rc=$?
    fi

    [ "$rc" -eq 0 ]
    [ "$branch" = "" ]
}

@test "git_get_current_branch does not use pushd or popd" {
    local repo="$TEST_TMPDIR/repo"
    local branch="" rc

    init_git_repo "$repo"
    pushd() {
        printf 'unexpected pushd\n' >&2
        return 99
    }
    popd() {
        printf 'unexpected popd\n' >&2
        return 99
    }

    if git_get_current_branch "$repo" branch; then
        rc=0
    else
        rc=$?
    fi
    unset -f pushd popd

    [ "$rc" -eq 0 ]
    [ "$branch" = "main" ]
}

@test "git_get_current_branch usage names the current function" {
    bats_run git_get_current_branch

    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: git_get_current_branch <directory> <result_variable_name>"* ]]
    [[ "$output" != *"Usage: get_git_branch"* ]]
}

@test "git_get_current_branch rejects invalid result variable names" {
    local repo="$TEST_TMPDIR/repo"

    init_git_repo "$repo"

    bats_run git_get_current_branch "$repo" "bad-name"

    [ "$status" -eq 1 ]
    [[ "$output" == *"git_get_current_branch: result variable name must be a valid Bash variable name"* ]]
    [[ "$output" != *"invalid variable name"* ]]
}

@test "git_update_repo usage names the current function" {
    bats_run git_update_repo

    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: git_update_repo /path/to/repo [allowed_dirty_path] [expected_branch]"* ]]
    [[ "$output" != *"Usage: update_repo"* ]]
}

@test "git_update_repo skips dirty repositories when no dirty path is allowed" {
    local repo="$TEST_TMPDIR/repo"

    init_git_repo "$repo"
    printf 'base\n' > "$repo/data.txt"
    commit_all "$repo" "Initial commit"
    printf 'local change\n' > "$repo/data.txt"
    set_log_level DEBUG

    bats_run git_update_repo "$repo"

    [ "$status" -eq 0 ]
    [[ "$output" == *"has local changes; skipping auto-update"* ]]
}

@test "git_update_repo treats branch mismatch as a skip" {
    local repo="$TEST_TMPDIR/repo"

    init_git_repo "$repo"
    printf 'base\n' > "$repo/data.txt"
    commit_all "$repo" "Initial commit"
    set_log_level DEBUG

    bats_run git_update_repo "$repo" "" release

    [ "$status" -eq 0 ]
    [[ "$output" == *"not 'release'. Skipping update"* ]]
}

@test "git_update_repo fails clearly when origin remote is missing" {
    local before_head
    local repo="$TEST_TMPDIR/repo"

    init_git_repo "$repo"
    printf 'base\n' > "$repo/data.txt"
    commit_all "$repo" "Initial commit"
    before_head="$(git -C "$repo" rev-parse HEAD)"

    bats_run git_update_repo "$repo" "" main

    [ "$status" -eq 1 ]
    [[ "$output" == *"git pull failed on repo '$repo'"* ]]
    [ "$(git -C "$repo" rev-parse HEAD)" = "$before_head" ]
    [ "$(cat "$repo/data.txt")" = "base" ]
    [ -z "$(git -C "$repo" status --porcelain)" ]
}

@test "git_update_repo fails clearly when origin remote is unreachable" {
    local before_head
    local remote="$TEST_TMPDIR/remote.git"
    local repo="$TEST_TMPDIR/repo"

    create_tracked_repo_with_upstream "$repo" "$remote" "data.txt" "base"
    before_head="$(git -C "$repo" rev-parse HEAD)"
    git -C "$repo" remote set-url origin "$TEST_TMPDIR/missing-remote.git"

    bats_run git_update_repo "$repo" "" main

    [ "$status" -eq 1 ]
    [[ "$output" == *"git pull failed on repo '$repo'"* ]]
    [ "$(git -C "$repo" rev-parse HEAD)" = "$before_head" ]
    [ "$(cat "$repo/data.txt")" = "base" ]
    [ -z "$(git -C "$repo" status --porcelain)" ]
}

@test "git_update_repo fails on non-fast-forward updates without changing HEAD" {
    local before_head
    local other="$TEST_TMPDIR/other"
    local remote="$TEST_TMPDIR/remote.git"
    local repo="$TEST_TMPDIR/repo"

    create_tracked_repo_with_upstream "$repo" "$remote" "data.txt" "base"
    before_head="$(git -C "$repo" rev-parse HEAD)"

    git clone "$remote" "$other" >/dev/null 2>&1
    git -C "$other" config user.name "Bats Test"
    git -C "$other" config user.email "bats@example.com"
    printf 'rewritten remote\n' > "$other/data.txt"
    git -C "$other" add data.txt
    git -C "$other" commit --amend -m "Rewrite remote history" >/dev/null 2>&1
    git -C "$other" push --force origin main >/dev/null 2>&1

    bats_run git_update_repo "$repo" "" main

    [ "$status" -eq 1 ]
    [[ "$output" == *"git pull failed on repo '$repo'"* ]]
    [ "$(git -C "$repo" rev-parse HEAD)" = "$before_head" ]
    [ "$(cat "$repo/data.txt")" = "base" ]
    [ -z "$(git -C "$repo" status --porcelain)" ]
}

@test "git_update_repo lets git protect untracked files from incoming tracked paths" {
    local before_head
    local other="$TEST_TMPDIR/other"
    local remote="$TEST_TMPDIR/remote.git"
    local repo="$TEST_TMPDIR/repo"

    create_tracked_repo_with_upstream "$repo" "$remote" "data.txt" "base"
    before_head="$(git -C "$repo" rev-parse HEAD)"
    git clone "$remote" "$other" >/dev/null 2>&1
    git -C "$other" config user.name "Bats Test"
    git -C "$other" config user.email "bats@example.com"
    printf 'incoming tracked\n' > "$other/local-notes.md"
    git -C "$other" add local-notes.md
    git -C "$other" commit -m "Add tracked notes" >/dev/null 2>&1
    git -C "$other" push origin main >/dev/null 2>&1
    printf 'local untracked\n' > "$repo/local-notes.md"

    bats_run git_update_repo "$repo" "" main

    [ "$status" -eq 1 ]
    [[ "$output" == *"git pull failed on repo '$repo'"* ]]
    [ "$(git -C "$repo" rev-parse HEAD)" = "$before_head" ]
    [ "$(cat "$repo/local-notes.md")" = "local untracked" ]
    ! git -C "$repo" ls-files --error-unmatch local-notes.md >/dev/null 2>&1
}

@test "git_update_repo accepts main as the detected update branch" {
    local repo="$TEST_TMPDIR/repo"

    init_git_repo "$repo"
    git -C "$repo" checkout -B main >/dev/null 2>&1
    printf 'base\n' > "$repo/data.txt"
    commit_all "$repo" "Initial commit"
    printf 'local change\n' > "$repo/data.txt"
    set_log_level DEBUG

    bats_run git_update_repo "$repo"

    [ "$status" -eq 0 ]
    [[ "$output" == *"has local changes; skipping auto-update"* ]]
    [[ "$output" != *"not 'main'"* ]]
}

@test "_git_expected_update_branch returns main when origin has main" {
    local repo="$TEST_TMPDIR/repo"
    local branch

    init_git_repo "$repo"
    printf 'base\n' > "$repo/data.txt"
    commit_all "$repo" "Initial commit"
    git -C "$repo" update-ref refs/remotes/origin/main HEAD
    git -C "$repo" checkout --detach >/dev/null 2>&1
    git -C "$repo" branch -D main >/dev/null 2>&1

    pushd "$repo" >/dev/null
    branch="$(_git_expected_update_branch)"
    popd >/dev/null

    [ "$branch" = "main" ]
}

@test "_git_expected_update_branch returns master when origin only has master" {
    local repo="$TEST_TMPDIR/repo"
    local branch

    init_git_repo "$repo"
    printf 'base\n' > "$repo/data.txt"
    commit_all "$repo" "Initial commit"
    git -C "$repo" update-ref refs/remotes/origin/master HEAD
    git -C "$repo" checkout --detach >/dev/null 2>&1
    git -C "$repo" branch -D main >/dev/null 2>&1

    pushd "$repo" >/dev/null
    branch="$(_git_expected_update_branch)"
    popd >/dev/null

    [ "$branch" = "master" ]
}

@test "_git_expected_update_branch falls back to main without main or master refs" {
    local repo="$TEST_TMPDIR/repo"
    local branch

    init_git_repo "$repo"

    pushd "$repo" >/dev/null
    branch="$(_git_expected_update_branch)"
    popd >/dev/null

    [ "$branch" = "main" ]
}

@test "_git_only_path_dirty accepts multiple dirty files under an allowed directory" {
    local repo="$TEST_TMPDIR/repo"
    local rc

    init_git_repo "$repo"
    mkdir -p "$repo/shared"
    printf 'one\n' > "$repo/shared/one.txt"
    printf 'two\n' > "$repo/shared/two.txt"
    commit_all "$repo" "Initial commit"
    printf 'local one\n' > "$repo/shared/one.txt"
    printf 'local two\n' > "$repo/shared/two.txt"

    pushd "$repo" >/dev/null
    _git_only_path_dirty "shared"
    rc=$?
    popd >/dev/null

    [ "$rc" -eq 0 ]
}

@test "_git_only_path_dirty does not treat sibling path prefixes as allowed" {
    local repo="$TEST_TMPDIR/repo"
    local rc

    init_git_repo "$repo"
    mkdir -p "$repo/shared"
    printf 'one\n' > "$repo/shared/one.txt"
    printf 'other\n' > "$repo/shared-other.txt"
    commit_all "$repo" "Initial commit"
    printf 'local one\n' > "$repo/shared/one.txt"
    printf 'local other\n' > "$repo/shared-other.txt"

    pushd "$repo" >/dev/null
    set +e
    _git_only_path_dirty "shared"
    rc=$?
    set -e
    popd >/dev/null

    [ "$rc" -eq 1 ]
}

@test "_git_only_path_dirty rejects renames from outside the allowed path" {
    local repo="$TEST_TMPDIR/repo"
    local rc

    init_git_repo "$repo"
    mkdir -p "$repo/shared" "$repo/src"
    printf 'one\n' > "$repo/src/one.txt"
    commit_all "$repo" "Initial commit"
    git -C "$repo" mv src/one.txt shared/one.txt

    pushd "$repo" >/dev/null
    set +e
    _git_only_path_dirty "shared"
    rc=$?
    set -e
    popd >/dev/null

    [ "$rc" -eq 1 ]
}

@test "_git_only_path_dirty accepts renames inside the allowed path" {
    local repo="$TEST_TMPDIR/repo"
    local rc

    init_git_repo "$repo"
    mkdir -p "$repo/shared"
    printf 'one\n' > "$repo/shared/one.txt"
    commit_all "$repo" "Initial commit"
    git -C "$repo" mv shared/one.txt shared/two.txt

    pushd "$repo" >/dev/null
    _git_only_path_dirty "shared"
    rc=$?
    popd >/dev/null

    [ "$rc" -eq 0 ]
}

@test "git_update_repo cleans up temp log without changing RETURN trap" {
    local repo="$TEST_TMPDIR/repo"
    local temp_dir="$TEST_TMPDIR/git-temp"
    local return_trap

    mkdir -p "$temp_dir"
    init_git_repo "$repo"
    printf 'base\n' > "$repo/data.txt"
    commit_all "$repo" "Initial commit"
    printf 'local change\n' > "$repo/data.txt"

    trap 'printf "outer return trap\n"' RETURN
    TMPDIR="$temp_dir" bats_run git_update_repo "$repo"
    return_trap="$(trap -p RETURN)"
    trap - RETURN

    [ "$status" -eq 0 ]
    [[ "$return_trap" == *"outer return trap"* ]]
    ! compgen -G "$temp_dir/git_log.*" >/dev/null
}

@test "_git_update_repo_finish removes temp log after success" {
    local git_log="$TEST_TMPDIR/git.log"

    printf 'pull output\n' > "$git_log"

    bats_run _git_update_repo_finish "$git_log" false 0

    [ "$status" -eq 0 ]
    [ ! -e "$git_log" ]
}

@test "_git_update_repo_finish preserves an existing RETURN trap" {
    local git_log="$TEST_TMPDIR/git.log"
    local return_trap

    printf 'pull output\n' > "$git_log"
    trap 'printf "outer return trap\n"' RETURN

    bats_run _git_update_repo_finish "$git_log" false 0
    return_trap="$(trap -p RETURN)"
    trap - RETURN

    [ "$status" -eq 0 ]
    [[ "$return_trap" == *"outer return trap"* ]]
    [ ! -e "$git_log" ]
}

@test "_git_pull_with_retry retries once after a transient pull failure" {
    local git_log="$TEST_TMPDIR/git.log"
    local pull_count="$TEST_TMPDIR/pull-count"

    printf '0\n' > "$pull_count"
    git() {
        local count

        if [[ "${1:-}" == "pull" ]]; then
            count="$(cat "$pull_count")"
            count=$((count + 1))
            printf '%s\n' "$count" > "$pull_count"
            printf 'pull attempt %s\n' "$count" >&2
            [[ "$count" -ge 2 ]]
            return $?
        fi
        command git "$@"
    }

    bats_run _git_pull_with_retry "$git_log"
    unset -f git

    [ "$status" -eq 0 ]
    [ "$(cat "$pull_count")" = "2" ]
    [[ "$output" == *"git pull failed on attempt 1; retrying once."* ]]
    [ "$(cat "$git_log")" = "pull attempt 2" ]
}

@test "_git_pull_with_retry honors configured max attempts" {
    local git_log="$TEST_TMPDIR/git.log"
    local pull_count="$TEST_TMPDIR/pull-count"

    printf '0\n' > "$pull_count"
    git() {
        local count

        if [[ "${1:-}" == "pull" ]]; then
            count="$(cat "$pull_count")"
            count=$((count + 1))
            printf '%s\n' "$count" > "$pull_count"
            printf 'pull attempt %s\n' "$count" >&2
            [[ "$count" -ge 3 ]]
            return $?
        fi
        command git "$@"
    }

    BASE_GIT_PULL_MAX_ATTEMPTS=3 bats_run _git_pull_with_retry "$git_log"
    unset -f git

    [ "$status" -eq 0 ]
    [ "$(cat "$pull_count")" = "3" ]
    [[ "$output" == *"git pull failed on attempt 2; retrying (attempt 3 of 3)."* ]]
    [ "$(cat "$git_log")" = "pull attempt 3" ]
}

@test "_git_pull_with_retry falls back for invalid configured max attempts" {
    local git_log="$TEST_TMPDIR/git.log"
    local max_attempts
    local pull_count="$TEST_TMPDIR/pull-count"

    git() {
        local count

        if [[ "${1:-}" == "pull" ]]; then
            count="$(cat "$pull_count")"
            count=$((count + 1))
            printf '%s\n' "$count" > "$pull_count"
            printf 'pull attempt %s\n' "$count" >&2
            [[ "$count" -ge 2 ]]
            return $?
        fi
        command git "$@"
    }

    for max_attempts in abc 0 -1; do
        printf '0\n' > "$pull_count"
        : > "$git_log"

        BASE_GIT_PULL_MAX_ATTEMPTS="$max_attempts" bats_run _git_pull_with_retry "$git_log"

        [ "$status" -eq 0 ]
        [ "$(cat "$pull_count")" = "2" ]
        [[ "$output" == *"BASE_GIT_PULL_MAX_ATTEMPTS must be a positive integer; using 2."* ]]
        [[ "$output" == *"git pull failed on attempt 1; retrying once."* ]]
        [ "$(cat "$git_log")" = "pull attempt 2" ]
    done
    unset -f git
}

@test "_git_pull_with_retry fails after two pull attempts" {
    local git_log="$TEST_TMPDIR/git.log"
    local pull_count="$TEST_TMPDIR/pull-count"

    printf '0\n' > "$pull_count"
    git() {
        local count

        if [[ "${1:-}" == "pull" ]]; then
            count="$(cat "$pull_count")"
            count=$((count + 1))
            printf '%s\n' "$count" > "$pull_count"
            printf 'pull attempt %s\n' "$count" >&2
            return 1
        fi
        command git "$@"
    }

    bats_run _git_pull_with_retry "$git_log"
    unset -f git

    [ "$status" -eq 1 ]
    [ "$(cat "$pull_count")" = "2" ]
    [[ "$output" == *"git pull failed on attempt 1; retrying once."* ]]
    [ "$(cat "$git_log")" = "pull attempt 2" ]
}

@test "check_script_up_to_date reports success for an up-to-date tracked script" {
    local repo="$TEST_TMPDIR/repo"
    local remote="$TEST_TMPDIR/remote.git"
    local script_path="$repo/scripts/tool.sh"

    create_tracked_repo_with_upstream "$repo" "$remote" "scripts/tool.sh" "#!/usr/bin/env bash"

    bats_run check_script_up_to_date "$script_path"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Repository is up to date with origin/main."* ]]
}

@test "check_script_up_to_date uses local remote-tracking refs by default" {
    local other="$TEST_TMPDIR/other"
    local repo="$TEST_TMPDIR/repo"
    local remote="$TEST_TMPDIR/remote.git"
    local script_path="$repo/scripts/tool.sh"

    create_tracked_repo_with_upstream "$repo" "$remote" "scripts/tool.sh" "#!/usr/bin/env bash"
    git clone "$remote" "$other" >/dev/null 2>&1
    git -C "$other" config user.name "Bats Test"
    git -C "$other" config user.email "bats@example.com"
    printf 'echo remote\n' >> "$other/scripts/tool.sh"
    git -C "$other" add scripts/tool.sh
    git -C "$other" commit -m "Update remote script" >/dev/null 2>&1
    git -C "$other" push origin main >/dev/null 2>&1

    bats_run check_script_up_to_date "$script_path"

    [ "$status" -eq 0 ]
    [[ "$output" != *"Using local remote-tracking refs"* ]]
    [[ "$output" == *"Repository is up to date with origin/main."* ]]
}

@test "check_script_up_to_date reports local remote-tracking refs at debug level" {
    local repo="$TEST_TMPDIR/repo"
    local remote="$TEST_TMPDIR/remote.git"
    local script_path="$repo/scripts/tool.sh"

    create_tracked_repo_with_upstream "$repo" "$remote" "scripts/tool.sh" "#!/usr/bin/env bash"
    set_log_level DEBUG

    bats_run check_script_up_to_date "$script_path"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Using local remote-tracking refs; pass --fetch for a live remote check."* ]]
    [[ "$output" == *"Repository is up to date with origin/main."* ]]
}

@test "check_script_up_to_date fetches before comparing when requested" {
    local other="$TEST_TMPDIR/other"
    local repo="$TEST_TMPDIR/repo"
    local remote="$TEST_TMPDIR/remote.git"
    local script_path="$repo/scripts/tool.sh"

    create_tracked_repo_with_upstream "$repo" "$remote" "scripts/tool.sh" "#!/usr/bin/env bash"
    git clone "$remote" "$other" >/dev/null 2>&1
    git -C "$other" config user.name "Bats Test"
    git -C "$other" config user.email "bats@example.com"
    printf 'echo remote\n' >> "$other/scripts/tool.sh"
    git -C "$other" add scripts/tool.sh
    git -C "$other" commit -m "Update remote script" >/dev/null 2>&1
    git -C "$other" push origin main >/dev/null 2>&1

    bats_run check_script_up_to_date --fetch "$script_path"

    [ "$status" -eq 2 ]
    [[ "$output" == *"Fetched upstream state before latest-version check."* ]]
    [[ "$output" == *"Repository is 1 commit(s) behind origin/main"* ]]
}

@test "check_script_up_to_date returns 3 for a dirty tracked script" {
    local repo="$TEST_TMPDIR/repo"
    local remote="$TEST_TMPDIR/remote.git"
    local script_path="$repo/scripts/tool.sh"

    create_tracked_repo_with_upstream "$repo" "$remote" "scripts/tool.sh" "#!/usr/bin/env bash"
    printf 'echo dirty\n' >> "$script_path"

    bats_run check_script_up_to_date "$script_path"

    [ "$status" -eq 3 ]
    [[ "$output" == *"has local modifications"* ]]
}

@test "check_script_up_to_date returns 3 when a script is both behind and dirty" {
    local other="$TEST_TMPDIR/other"
    local repo="$TEST_TMPDIR/repo"
    local remote="$TEST_TMPDIR/remote.git"
    local script_path="$repo/scripts/tool.sh"

    create_tracked_repo_with_upstream "$repo" "$remote" "scripts/tool.sh" "#!/usr/bin/env bash"
    git clone "$remote" "$other" >/dev/null 2>&1
    git -C "$other" config user.name "Bats Test"
    git -C "$other" config user.email "bats@example.com"
    printf 'echo remote\n' >> "$other/scripts/tool.sh"
    git -C "$other" add scripts/tool.sh
    git -C "$other" commit -m "Update remote script" >/dev/null 2>&1
    git -C "$other" push origin main >/dev/null 2>&1
    printf 'echo dirty\n' >> "$script_path"

    bats_run check_script_up_to_date --fetch "$script_path"

    [ "$status" -eq 3 ]
    [[ "$output" == *"has local modifications"* ]]
    [[ "$output" == *"Repository is 1 commit(s) behind origin/main"* ]]
}
