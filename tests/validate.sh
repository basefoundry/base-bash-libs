#!/usr/bin/env bash

set -e

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1

required_files=(
  README.md
  VERSION
  CHANGELOG.md
  CONTRIBUTING.md
  .github/pull_request_template.md
  .github/base-project.yml
  LICENSE
  base_manifest.yaml
  .github/workflows/project-intake.yml
  .github/workflows/tests.yml
  examples/std-usage.sh
  lib/bash/README.md
  lib/bash/std/lib_std.sh
  lib/bash/std/tests/lib_std.bats
  lib/bash/file/lib_file.sh
  lib/bash/file/tests/lib_file.bats
  lib/bash/git/lib_git.sh
  lib/bash/git/tests/lib_git.bats
  lib/bash/tests/test_helper.sh
)

cd "$repo_root" || exit 1

for file in "${required_files[@]}"; do
  [[ -f "$file" ]] || {
    printf 'Missing required file: %s\n' "$file" >&2
    exit 1
  }
done

printf 'Repository baseline is present.\n'

for command in shellcheck bats; do
  command -v "$command" >/dev/null 2>&1 || {
    printf "Required validation command '%s' was not found.\n" "$command" >&2
    exit 1
  }
done

shellcheck --severity=error \
  tests/validate.sh \
  examples/std-usage.sh \
  lib/bash/std/lib_std.sh \
  lib/bash/file/lib_file.sh \
  lib/bash/git/lib_git.sh \
  lib/bash/tests/test_helper.sh

bats \
  lib/bash/std/tests/lib_std.bats \
  lib/bash/file/tests/lib_file.bats \
  lib/bash/git/tests/lib_git.bats

examples/std-usage.sh >/dev/null

printf 'Bash library validation passed.\n'
