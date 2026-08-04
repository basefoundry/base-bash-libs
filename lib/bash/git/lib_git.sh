# shellcheck shell=bash
#
# lib_git.sh: Git operations
#

[[ -n "${__lib_git_sourced__:-}" ]] && return 0
if [[ "${BASE_BASH_LIBS_STDLIB_LOADED:-}" != "1" ]]; then
    printf '%s\n' "Error: lib_git.sh requires lib_std.sh to be sourced first." >&2
    return 1 2>/dev/null || exit 1
fi
readonly __lib_git_sourced__=1

git_detect_default_branch() {
    if (($# != 2)); then
        log_error -l base_bash_libs.git "Usage: git_detect_default_branch <repo_dir> <result_variable_name>"
        return 1
    fi
    __std_assert_public_variable_names__ git_detect_default_branch "${2-}" || return 1

    local __git_detect_repo_dir="$1"
    local __git_detect_result_name="$2"
    local __git_detect_branch

    if [[ -z "$__git_detect_repo_dir" || -z "$__git_detect_result_name" ]]; then
        log_error -l base_bash_libs.git "Usage: git_detect_default_branch <repo_dir> <result_variable_name>"
        return 1
    fi
    assert_variable_name "$__git_detect_result_name" || return 1
    __std_assert_writable_output__ git_detect_default_branch "$__git_detect_result_name" || return 1

    if __git_detect_branch="$(git -C "$__git_detect_repo_dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"; then
        __git_detect_branch="${__git_detect_branch#origin/}"
        if [[ -n "$__git_detect_branch" ]]; then
            printf -v "$__git_detect_result_name" '%s' "$__git_detect_branch"
            return 0
        fi
    fi

    if git -C "$__git_detect_repo_dir" show-ref --verify --quiet refs/remotes/origin/main ||
        git -C "$__git_detect_repo_dir" show-ref --verify --quiet refs/heads/main; then
        printf -v "$__git_detect_result_name" '%s' main
        return 0
    fi

    if git -C "$__git_detect_repo_dir" show-ref --verify --quiet refs/remotes/origin/master ||
        git -C "$__git_detect_repo_dir" show-ref --verify --quiet refs/heads/master; then
        printf -v "$__git_detect_result_name" '%s' master
        return 0
    fi

    return 1
}

git_worktree_path_for_branch() {
    if (($# < 1 || $# > 2)); then
        log_error -l base_bash_libs.git "Usage: git_worktree_path_for_branch <branch> [repo_dir]"
        return 1
    fi

    local branch="$1"
    local repo_dir="${2:-}"
    local target_ref="refs/heads/$branch"
    local line path="" ref output
    local -a git_cmd=(git)

    [[ -n "$branch" ]] || {
        log_error -l base_bash_libs.git "Usage: git_worktree_path_for_branch <branch> [repo_dir]"
        return 1
    }

    [[ -z "$repo_dir" ]] || git_cmd=(git -C "$repo_dir")
    if ! output="$("${git_cmd[@]+"${git_cmd[@]}"}" worktree list --porcelain 2>&1)"; then
        log_error -l base_bash_libs.git "Unable to list Git worktrees."
        return 1
    fi
    while IFS= read -r line; do
        case "$line" in
            "worktree "*)
                path="${line#worktree }"
                ;;
            "branch "*)
                ref="${line#branch }"
                if [[ "$ref" == "$target_ref" ]]; then
                    printf '%s\n' "$path"
                    return 0
                fi
                ;;
        esac
    done <<<"$output"

    return 1
}

git_list_worktree_branches() {
    if (($# > 1)); then
        log_error -l base_bash_libs.git "Usage: git_list_worktree_branches [repo_dir]"
        return 1
    fi

    local repo_dir="${1:-}"
    local line path="" branch="" output
    local -a git_cmd=(git)

    [[ -z "$repo_dir" ]] || git_cmd=(git -C "$repo_dir")
    if ! output="$("${git_cmd[@]+"${git_cmd[@]}"}" worktree list --porcelain 2>&1)"; then
        log_error -l base_bash_libs.git "Unable to list Git worktrees."
        return 1
    fi
    output+=$'\n'

    while IFS= read -r line; do
        case "$line" in
            "")
                if [[ -n "$path" && -n "$branch" ]]; then
                    branch="${branch#refs/heads/}"
                    printf '%s\t%s\n' "$path" "$branch"
                fi
                path=""
                branch=""
                ;;
            "worktree "*)
                path="${line#worktree }"
                ;;
            "branch "*)
                branch="${line#branch }"
                ;;
        esac
    done <<<"$output"
}

git_branch_upstream() {
    if (($# != 2)); then
        log_error -l base_bash_libs.git "Usage: git_branch_upstream <repo_dir> <branch>"
        return 1
    fi

    local repo_dir="$1"
    local branch="$2"

    if [[ -z "$repo_dir" || -z "$branch" ]]; then
        log_error -l base_bash_libs.git "Usage: git_branch_upstream <repo_dir> <branch>"
        return 1
    fi

    git -C "$repo_dir" for-each-ref --format='%(upstream:short)' "refs/heads/$branch"
}

git_branch_merged_to_ref() {
    if (($# != 3)); then
        log_error -l base_bash_libs.git "Usage: git_branch_merged_to_ref <repo_dir> <branch> <ref>"
        return 1
    fi

    local repo_dir="$1"
    local branch="$2"
    local ref="$3"

    if [[ -z "$repo_dir" || -z "$branch" || -z "$ref" ]]; then
        log_error -l base_bash_libs.git "Usage: git_branch_merged_to_ref <repo_dir> <branch> <ref>"
        return 1
    fi

    git -C "$repo_dir" merge-base --is-ancestor "refs/heads/$branch" "$ref" >/dev/null 2>&1
}

git_list_remote_branches() {
    if (($# > 1)); then
        log_error -l base_bash_libs.git "Usage: git_list_remote_branches [repo_dir]"
        return 1
    fi

    local repo_dir="${1:-.}"
    local output ref _sha

    if ! output="$(git -C "$repo_dir" ls-remote --heads origin)"; then
        log_error -l base_bash_libs.git "Unable to list remote branches from origin."
        return 1
    fi
    while IFS=$' \t' read -r _sha ref; do
        [[ "$ref" == refs/heads/* ]] || continue
        printf '%s\n' "${ref#refs/heads/}"
    done <<<"$output"
}

#
# Returns success when tracked changes are limited to one repo-relative path.
#
# @param $1 allowed_path Path in repository root that may be dirty (for example "shared").
#
__git_path_matches_allowed_path__() {
    (($# == 2)) || return 1

    local path="$1" allowed_path="$2"

    [[ "$path" == "$allowed_path" || "$path" == "$allowed_path/"* ]]
}

__git_only_path_dirty__() {
    (($# == 1)) || return 1

    local allowed_path="$1"
    local status_file status_record status_code path related_path

    std_make_temp_file status_file base-git-status || return 1
    if ! git status --porcelain=v1 --untracked-files=no --ignore-submodules=none -z > "$status_file"; then
        std_unregister_cleanup_path "$status_file"
        rm -f -- "$status_file"
        return 1
    fi
    if [[ ! -s "$status_file" ]]; then
        std_unregister_cleanup_path "$status_file"
        rm -f -- "$status_file"
        return 1
    fi

    while IFS= read -r -d '' status_record; do
        [[ -n "$status_record" ]] || continue
        status_code="${status_record:0:2}"
        path="${status_record:3}"
        if ! __git_path_matches_allowed_path__ "$path" "$allowed_path"; then
            std_unregister_cleanup_path "$status_file"
            rm -f -- "$status_file"
            return 1
        fi

        if [[ "$status_code" == *R* || "$status_code" == *C* ]]; then
            if ! IFS= read -r -d '' related_path ||
                ! __git_path_matches_allowed_path__ "$related_path" "$allowed_path"; then
                std_unregister_cleanup_path "$status_file"
                rm -f -- "$status_file"
                return 1
            fi
        fi
    done < "$status_file"

    std_unregister_cleanup_path "$status_file"
    rm -f -- "$status_file"
    return 0
}

__git_expected_update_branch__() {
    (($# <= 1)) || return 1

    local configured_branch="${1:-}"
    local default_branch

    if [[ -n "$configured_branch" ]]; then
        printf '%s\n' "$configured_branch"
        return 0
    fi

    if default_branch="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"; then
        default_branch="${default_branch#origin/}"
        if [[ -n "$default_branch" ]]; then
            printf '%s\n' "$default_branch"
            return 0
        fi
    fi

    if git show-ref --verify --quiet refs/remotes/origin/main; then
        printf '%s\n' main
        return 0
    fi

    if git show-ref --verify --quiet refs/remotes/origin/master; then
        printf '%s\n' master
        return 0
    fi

    if git show-ref --verify --quiet refs/heads/main; then
        printf '%s\n' main
        return 0
    fi

    if git show-ref --verify --quiet refs/heads/master; then
        printf '%s\n' master
        return 0
    fi

    printf '%s\n' main
}

__git_update_repo_finish__() {
    local git_log="${1:-}"
    local should_popd="${2:-false}"
    local status="${3:-0}"
    local submodule_log="${4:-}"

    if [[ "$should_popd" == true ]]; then
        popd >/dev/null || status=1
    fi

    if [[ -n "$git_log" ]]; then
        rm -f -- "$git_log"
        std_unregister_cleanup_path "$git_log"
    fi
    if [[ -n "$submodule_log" ]]; then
        rm -f -- "$submodule_log"
        std_unregister_cleanup_path "$submodule_log"
    fi
    return "$status"
}

__git_pull_with_retry__() {
    (($# == 1)) || return 1

    local git_log="$1"
    local max_attempts="${BASE_GIT_PULL_MAX_ATTEMPTS:-2}"
    local attempt=1

    if [[ ! "$max_attempts" =~ ^[0-9]+$ ]] || ((max_attempts < 1)); then
        log_warn -l base_bash_libs.git "BASE_GIT_PULL_MAX_ATTEMPTS must be a positive integer; using 2."
        max_attempts=2
    fi

    while ((attempt <= max_attempts)); do
        if git pull --ff-only >"$git_log" 2>&1; then
            if ((attempt > 1)); then
                log_debug -l base_bash_libs.git "git pull succeeded on attempt $attempt."
            fi
            return 0
        fi

        if ((attempt == max_attempts)); then
            return 1
        fi

        if ((max_attempts == 2)); then
            log_warn -l base_bash_libs.git "git pull failed on attempt $attempt; retrying once."
        else
            log_warn -l base_bash_libs.git "git pull failed on attempt $attempt; retrying (attempt $((attempt + 1)) of $max_attempts)."
        fi
        [[ -s "$git_log" ]] && log_debug_file -l base_bash_libs.git "$git_log"
        attempt=$((attempt + 1))
    done
}

#
# Safely updates a Git repository and its submodules after checking that the
# current branch is the repo default branch or an explicit expected branch.
#
# @param $1 git_repo           The path to the local git repository.
# @param $2 allowed_dirty_path Optional repo-relative path that may be dirty.
# @param $3 expected_branch    Optional branch name to require instead of auto-detecting.
#
# Environment:
#   BASE_GIT_PULL_MAX_ATTEMPTS Positive integer retry count for `git pull --ff-only`; defaults to 2.
#
git_update_repo() {
    if (($# < 1 || $# > 3)); then
        log_info -l base_bash_libs.git "Usage: git_update_repo /path/to/repo [allowed_dirty_path] [expected_branch]"
        return 1
    fi

    local git_repo="$1"
    local allowed_dirty_path="${2:-}"
    local expected_branch="${3:-}"
    local git_log submodule_log=""

    if [[ -z "$git_repo" ]]; then
        log_error -l base_bash_libs.git "No git repository path provided."
        log_info -l base_bash_libs.git "Usage: git_update_repo /path/to/repo [allowed_dirty_path] [expected_branch]"
        return 1
    fi

    if [[ ! -d "$git_repo" ]]; then
        log_error -l base_bash_libs.git "Git repo not found at '$git_repo'"
        return 1
    fi

    std_make_temp_file git_log git_log || {
        log_error -l base_bash_libs.git "Unable to create temporary git log file."
        return 1
    }
    # git_update_repo intentionally works inside the target repository because
    # the submodule update sequence below needs the repository as its cwd.
    if ! pushd "$git_repo" > /dev/null; then
        # If cd fails, we can't proceed.
        __git_update_repo_finish__ "$git_log" false 1
        return $?
    fi

    # Check if it's a valid git repo
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        log_error -l base_bash_libs.git "'$git_repo' is not a Git repository."
        __git_update_repo_finish__ "$git_log" true 1
        return $?
    fi

    # Make sure the current branch is the expected update branch.
    local current_branch
    expected_branch="$(__git_expected_update_branch__ "$expected_branch")"
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$current_branch" != "$expected_branch" ]]; then
        log_debug -l base_bash_libs.git "Current branch of '$git_repo' is '${current_branch}', not '$expected_branch'. Skipping update."
        __git_update_repo_finish__ "$git_log" true 0
        return $?
    fi

    local dirty=false
    if ! git diff --quiet; then
        dirty=true
    fi
    if ! git diff --cached --quiet; then
        dirty=true
    fi
    if [[ "$dirty" == true ]]; then
        if [[ -n "$allowed_dirty_path" ]] && __git_only_path_dirty__ "$allowed_dirty_path"; then
            log_debug -l base_bash_libs.git "Repo '$git_repo' only has tracked changes in '$allowed_dirty_path'; attempting git pull."
        else
            log_debug -l base_bash_libs.git "Repo '$git_repo' has local changes; skipping auto-update. Commit or stash to enable git pull."
        __git_update_repo_finish__ "$git_log" true 0
            return $?
        fi
    fi

    if ! __git_pull_with_retry__ "$git_log"; then
        log_error -l base_bash_libs.git "git pull failed on repo '$git_repo'"
        [[ -s "$git_log" ]] && log_info_file -l base_bash_libs.git "$git_log"
        __git_update_repo_finish__ "$git_log" true 1
        return $?
    fi

    # it is safe to run submodule commands even if the repo has no submodules
    if ! std_make_temp_file submodule_log git-submodule-log; then
        log_error -l base_bash_libs.git "Unable to create temporary submodule log file."
        __git_update_repo_finish__ "$git_log" true 1
        return $?
    fi
    if ! { git submodule init && git submodule sync && git submodule update; } >"$submodule_log" 2>&1; then
        log_error -l base_bash_libs.git "git submodule update failed on repo '$git_repo'"
        [[ -s "$submodule_log" ]] && log_info_file -l base_bash_libs.git "$submodule_log"
        __git_update_repo_finish__ "$git_log" true 1 "$submodule_log"
        return $?
    fi

    log_debug -l base_bash_libs.git "Git repo '$git_repo' updated to latest '$expected_branch'"
    __git_update_repo_finish__ "$git_log" true 0 "$submodule_log"
    return $?
}

#
# Gets the currently checked-out branch of a Git repository without changing directories.
#
# This function safely checks a directory, determines if it's a Git repository,
# and returns the current branch name via a name reference (nameref).
#
# @param $1 target_dir     The path to the directory to check.
# @param $2 result_var_name The name of the variable in the calling scope
#                          that will receive the output.
#
# Returns:
#   - The branch name (e.g., "main", "feature/login") is stored in the result variable.
#   - "detached head" if the repository is in a detached HEAD state.
#   - An empty string "" if the directory doesn't exist or is not a Git repo.
#   - The function itself returns an exit code of 0 on success, 1 on invalid usage.
#
git_get_current_branch() {
    if (($# != 2)); then
        log_error -l base_bash_libs.git "Usage: git_get_current_branch <directory> <result_variable_name>"
        return 1
    fi
    __std_assert_public_variable_names__ git_get_current_branch "${2-}" || return 1

    local __git_branch_target_dir="$1"
    local __git_branch_result_name="$2"

    # --- Argument Validation ---
    if [[ -z "$__git_branch_target_dir" || -z "$__git_branch_result_name" ]]; then
        log_error -l base_bash_libs.git "Usage: git_get_current_branch <directory> <result_variable_name>"
        return 1
    fi
    if ! __is_valid_variable_name__ "$__git_branch_result_name"; then
        log_error -l base_bash_libs.git "git_get_current_branch: result variable name must be a valid Bash variable name."
        return 1
    fi
    __std_assert_writable_output__ git_get_current_branch "$__git_branch_result_name" || return 1

    printf -v "$__git_branch_result_name" '%s' ""

    if [[ ! -d "$__git_branch_target_dir" ]]; then
        return 0
    fi

    # Check if we are inside a Git repository.
    if ! git -C "$__git_branch_target_dir" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        # Not a Git repo, result is already an empty string.
        return 0
    fi

    # Use 'git symbolic-ref' to get the branch name.
    # It's the most reliable way to distinguish a branch from a detached HEAD.
    # -q (--quiet) suppresses errors and returns a non-zero exit code on failure.
    local __git_branch_name
    if __git_branch_name=$(git -C "$__git_branch_target_dir" symbolic-ref --short -q HEAD); then
        # Success: We are on a named branch.
        printf -v "$__git_branch_result_name" '%s' "$__git_branch_name"
    else
        # Failure: We are in a detached HEAD state.
        printf -v "$__git_branch_result_name" '%s' "detached head"
    fi

    return 0
}

#
# Checks whether a script appears up to date with its git upstream and logs status.
#
# @param $1 Optional --fetch to refresh remote-tracking refs before comparing.
# @param $2 script_path The path to a script file tracked in a git repo.
#
# Returns:
#   - 0 if the repository is current or ahead, or the check is skipped for a
#     documented non-error state (missing git, not a repo, untracked script,
#     detached HEAD, or missing upstream).
#   - 1 on invalid usage.
#   - 2 if the repository is behind its upstream (the script may be stale).
#   - 3 if the script has local modifications and the comparison completed or
#     was skipped for a documented non-error state.
#   - 4 if the repository has diverged from its upstream.
#   - 5 if Git metadata, diff, fetch, or comparison commands fail.
#
# Status precedence:
#   - A dirty script takes precedence over a successful comparison, including
#     behind, ahead, diverged, and known skip states.
#   - An operational failure takes precedence over the dirty status because the
#     result cannot be trusted.
#   - A failed comparison never reports the repository as up to date.
#
# Expected skip states are not failures, but they are always logged explicitly.
# They return 3 when the tracked script is dirty so callers cannot lose that
# fact merely because an upstream comparison is unavailable.
#
check_script_up_to_date() {
    local fetch_before_check=false script_path

    if (($# == 2)); then
        if [[ "$1" != "--fetch" ]]; then
            log_error -l base_bash_libs.git "Usage: check_script_up_to_date [--fetch] <script_path>"
            return 1
        fi
        fetch_before_check=true
        shift
    elif (($# != 1)) || [[ "$1" == "--fetch" ]]; then
        log_error -l base_bash_libs.git "Usage: check_script_up_to_date [--fetch] <script_path>"
        return 1
    fi
    script_path="$1"

    if [[ ! -e "$script_path" ]]; then
        log_warn -l base_bash_libs.git "Script '$script_path' not found; skipping latest-version check."
        return 0
    fi

    if ! command -v git &> /dev/null; then
        log_info -l base_bash_libs.git "git not available; skipping latest-version check."
        return 0
    fi

    local script_dir repo_root prefix rel_path
    script_dir=$(dirname -- "$script_path") || {
        log_error -l base_bash_libs.git "Unable to resolve the script directory for '$script_path'."
        return 5
    }

    local repo_probe repo_probe_status
    if repo_probe=$(git -C "$script_dir" rev-parse --is-inside-work-tree 2>&1); then
        if [[ "$repo_probe" != true ]]; then
            log_info -l base_bash_libs.git "Script '$script_path' is not in a Git worktree; skipping latest-version check."
            return 0
        fi
    else
        repo_probe_status=$?
        if [[ "$repo_probe" == *"not a git repository"* ||
            "$repo_probe" == *"not a git repo"* ]]; then
            log_info -l base_bash_libs.git "Not in a Git repo; skipping latest-version check."
            return 0
        fi
        log_error -l base_bash_libs.git "Unable to discover the Git repository for '$script_path' (git status $repo_probe_status)."
        return 5
    fi

    local repo_root_status
    if repo_root=$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null); then
        :
    else
        repo_root_status=$?
        log_error -l base_bash_libs.git "Unable to resolve the Git repository root for '$script_path' (git status $repo_root_status)."
        return 5
    fi
    local prefix_status
    if prefix=$(git -C "$script_dir" rev-parse --show-prefix 2>/dev/null); then
        :
    else
        prefix_status=$?
        log_error -l base_bash_libs.git "Unable to resolve the repo-relative path for '$script_path' (git status $prefix_status)."
        return 5
    fi
    rel_path="${prefix}$(basename -- "$script_path")"

    local tracked_status
    if git -C "$repo_root" ls-files --error-unmatch -- "$rel_path" >/dev/null 2>&1; then
        tracked_status=0
    else
        tracked_status=$?
    fi
    case "$tracked_status" in
        0)
            ;;
        1)
            log_info -l base_bash_libs.git "Script '$rel_path' is not tracked in git; skipping latest-version check."
            return 0
            ;;
        *)
            log_error -l base_bash_libs.git "Unable to determine whether '$rel_path' is tracked (git status $tracked_status)."
            return 5
            ;;
    esac

    local dirty=false diff_status
    if git -C "$repo_root" diff --quiet -- "$rel_path"; then
        diff_status=0
    else
        diff_status=$?
    fi
    case "$diff_status" in
        0)
            ;;
        1)
            dirty=true
            ;;
        *)
            log_error -l base_bash_libs.git "Unable to inspect working-tree changes for '$rel_path' (git status $diff_status)."
            return 5
            ;;
    esac
    if git -C "$repo_root" diff --cached --quiet -- "$rel_path"; then
        diff_status=0
    else
        diff_status=$?
    fi
    case "$diff_status" in
        0)
            ;;
        1)
            dirty=true
            ;;
        *)
            log_error -l base_bash_libs.git "Unable to inspect staged changes for '$rel_path' (git status $diff_status)."
            return 5
            ;;
    esac
    if [[ "$dirty" == true ]]; then
        log_warn -l base_bash_libs.git "Script '$rel_path' has local modifications; version may not match repo."
    fi

    local branch_name branch_status
    if branch_name=$(git -C "$repo_root" symbolic-ref --quiet --short HEAD 2>/dev/null); then
        :
    else
        branch_status=$?
        if ((branch_status == 1)); then
            log_info -l base_bash_libs.git "Repository is in a detached HEAD state; skipping latest-version check."
            [[ "$dirty" == true ]] && return 3
            return 0
        fi
        log_error -l base_bash_libs.git "Unable to determine the current Git branch (git status $branch_status)."
        return 5
    fi

    local upstream upstream_result upstream_status
    if upstream_result=$(git -C "$repo_root" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>&1); then
        upstream="$upstream_result"
    else
        upstream_status=$?
        if [[ "$upstream_result" == *"no upstream"* ||
            "$upstream_result" == *"does not have any upstream"* ]]; then
            log_info -l base_bash_libs.git "No upstream branch configured for '$branch_name'; skipping latest-version check."
            [[ "$dirty" == true ]] && return 3
            return 0
        fi
        log_error -l base_bash_libs.git "Unable to resolve the upstream for '$branch_name' (git status $upstream_status)."
        return 5
    fi
    if [[ -z "$upstream" || "$upstream" == *$'\n'* ]]; then
        log_error -l base_bash_libs.git "Git returned an invalid upstream for '$branch_name'."
        return 5
    fi

    if [[ "$fetch_before_check" == true ]]; then
        if git -C "$repo_root" fetch --quiet; then
            log_info -l base_bash_libs.git "Fetched upstream state before latest-version check."
        else
            log_error -l base_bash_libs.git "Unable to fetch upstream state for '$upstream'; freshness is unknown."
            return 5
        fi
    else
        log_debug -l base_bash_libs.git "Using local remote-tracking refs; pass --fetch for a live remote check."
    fi

    local behind ahead rev_list_status
    if behind=$(git -C "$repo_root" rev-list --count "HEAD..$upstream" 2>/dev/null); then
        :
    else
        rev_list_status=$?
        log_error -l base_bash_libs.git "Unable to compare HEAD with '$upstream' (git status $rev_list_status); freshness is unknown."
        return 5
    fi
    if ahead=$(git -C "$repo_root" rev-list --count "$upstream..HEAD" 2>/dev/null); then
        :
    else
        rev_list_status=$?
        log_error -l base_bash_libs.git "Unable to compare '$upstream' with HEAD (git status $rev_list_status); freshness is unknown."
        return 5
    fi
    if [[ ! "$behind" =~ ^[0-9]+$ || ! "$ahead" =~ ^[0-9]+$ ]]; then
        log_error -l base_bash_libs.git "Git returned invalid freshness counts for '$upstream'; freshness is unknown."
        return 5
    fi

    if ((behind > 0 && ahead > 0)); then
        log_warn -l base_bash_libs.git "Repository has diverged from $upstream ($behind commit(s) behind, $ahead commit(s) ahead)."
        [[ "$dirty" == true ]] && return 3
        return 4
    fi
    if ((behind > 0)); then
        log_warn -l base_bash_libs.git "Repository is $behind commit(s) behind $upstream. Script may be out of date."
        [[ "$dirty" == true ]] && return 3
        return 2
    fi
    if ((ahead > 0)); then
        log_info -l base_bash_libs.git "Repository is $ahead commit(s) ahead of $upstream."
    else
        log_info -l base_bash_libs.git "Repository is up to date with $upstream."
    fi

    [[ "$dirty" == true ]] && return 3
    return 0
}
