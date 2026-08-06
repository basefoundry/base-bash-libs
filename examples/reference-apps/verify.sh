#!/usr/bin/env bash

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)" || exit 1
launcher="$repo_root/bin/base-bash"
framework="$repo_root/lib/bash"

for app in installer release-helper ops-cli; do
    project="$repo_root/examples/reference-apps/$app"
    [[ -f "$project/lib/app.sh" && -f "$project/bin/app" ]] || {
        printf 'Reference application is incomplete: %s\n' "$app" >&2
        exit 1
    }
    BASE_BASH_LIBS_DIR="$framework" "$launcher" "$project/bin/app" --help >/dev/null || exit $?
done

printf 'Reference applications passed launcher smoke checks.\n'
