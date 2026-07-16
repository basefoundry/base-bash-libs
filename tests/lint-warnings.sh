#!/usr/bin/env bash

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
cd "$repo_root" || exit 1

run_stage() {
  local label="$1"
  local status
  shift

  if "$@"; then
    return 0
  else
    status=$?
  fi

  printf 'Validation stage failed: %s (exit %s).\n' "$label" "$status" >&2
  return "$status"
}

lint_files=(
  bin/base-bash
  tests/validate.sh
  tests/lint-warnings.sh
  examples/std-usage.sh
  examples/cookbook-cleanup-temp.sh
  examples/cookbook-args-lists-strings.sh
  lib/bash/std/lib_std.sh
  lib/bash/file/lib_file.sh
  lib/bash/git/lib_git.sh
  lib/bash/gh/lib_gh.sh
  lib/bash/str/lib_str.sh
  lib/bash/arg/lib_arg.sh
  lib/bash/list/lib_list.sh
  lib/bash/tests/test_helper.sh
  tests/launcher.bats
)

run_stage "ShellCheck warning profile" shellcheck --severity=warning "${lint_files[@]}" || exit $?
