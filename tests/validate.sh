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
  NOTICE
  base_manifest.yaml
  .github/workflows/project-intake.yml
  .github/workflows/tests.yml
  examples/std-usage.sh
  examples/cookbook-cleanup-temp.sh
  examples/cookbook-args-lists-strings.sh
  lib/bash/README.md
  lib/bash/std/lib_std.sh
  lib/bash/std/tests/lib_std.bats
  lib/bash/file/lib_file.sh
  lib/bash/file/tests/lib_file.bats
  lib/bash/git/lib_git.sh
  lib/bash/git/tests/lib_git.bats
  lib/bash/str/README.md
  lib/bash/str/lib_str.sh
  lib/bash/str/tests/lib_str.bats
  lib/bash/arg/README.md
  lib/bash/arg/lib_arg.sh
  lib/bash/arg/tests/lib_arg.bats
  lib/bash/list/README.md
  lib/bash/list/lib_list.sh
  lib/bash/list/tests/lib_list.bats
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

version=""
IFS= read -r version < VERSION || {
  printf 'Unable to read VERSION.\n' >&2
  exit 1
}

if ! grep -F "| \`$version\` | [Apache-2.0](LICENSE) |" README.md >/dev/null; then
  printf 'README.md top strip does not match VERSION (%s) and Apache-2.0 license metadata.\n' "$version" >&2
  exit 1
fi

if ! sed -n '1,30p' README.md | grep -F 'Requires Bash 4.2+' >/dev/null; then
  printf 'README.md must state the Bash 4.2+ requirement near the top-level entry point.\n' >&2
  exit 1
fi

stale_base_refs="$(grep -R -n -E 'codeforester/base|github.com/codeforester' README.md lib/bash/README.md || true)"
if [[ -n "$stale_base_refs" ]]; then
  printf 'README files must not use stale codeforester Base coordinates:\n%s\n' "$stale_base_refs" >&2
  exit 1
fi

if ! grep -F '      - main' .github/workflows/tests.yml >/dev/null; then
  printf 'Tests workflow must run push validation on the main branch.\n' >&2
  exit 1
fi

fix_comments="$(grep -R -n '# FIX:' lib/bash || true)"
if [[ -n "$fix_comments" ]]; then
  printf 'Production library files must not contain development # FIX: comments:\n%s\n' "$fix_comments" >&2
  exit 1
fi

for command in shellcheck bats; do
  command -v "$command" >/dev/null 2>&1 || {
    printf "Required validation command '%s' was not found.\n" "$command" >&2
    exit 1
  }
done

shellcheck --severity=error \
  tests/validate.sh \
  examples/std-usage.sh \
  examples/cookbook-cleanup-temp.sh \
  examples/cookbook-args-lists-strings.sh \
  lib/bash/std/lib_std.sh \
  lib/bash/file/lib_file.sh \
  lib/bash/git/lib_git.sh \
  lib/bash/str/lib_str.sh \
  lib/bash/arg/lib_arg.sh \
  lib/bash/list/lib_list.sh \
  lib/bash/tests/test_helper.sh

bats \
  lib/bash/std/tests/lib_std.bats \
  lib/bash/file/tests/lib_file.bats \
  lib/bash/git/tests/lib_git.bats \
  lib/bash/str/tests/lib_str.bats \
  lib/bash/arg/tests/lib_arg.bats \
  lib/bash/list/tests/lib_list.bats

examples/std-usage.sh >/dev/null
examples/cookbook-cleanup-temp.sh >/dev/null
examples/cookbook-args-lists-strings.sh >/dev/null

printf 'Bash library validation passed.\n'
