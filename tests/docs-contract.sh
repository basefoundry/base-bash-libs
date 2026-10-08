#!/usr/bin/env bash

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
cd "$repo_root" || exit 1

required=(
    docs/README.md
    docs/v2/quickstart.md
    docs/v2/architecture.md
    docs/v2/migration-v1.4-to-v2.md
    docs/ci-policy.md
    integrations.md
)
for file in "${required[@]}"; do
    [[ -f "$file" ]] || {
        printf 'Missing documentation contract file: %s\n' "$file" >&2
        exit 1
    }
done

if grep -R -n -E 'checkout[[:space:]]+main|/archive/refs/heads/main|git clone .*[^[:alnum:]]main([[:space:]]|$)' \
    docs/v2 README.md; then
    printf 'Adoption documentation must not install from an unreleased moving main branch.\n' >&2
    exit 1
fi

current_release="v$(< VERSION)"
grep -F "export BASE_BASH_LIBS_REF='$current_release'" docs/v2/quickstart.md > /dev/null || {
    printf 'The v2 quickstart must use the current published release reference.\n' >&2
    exit 1
}
for quickstart_contract_text in \
    'git -C vendor/base-bash-libs checkout --detach "$BASE_BASH_LIBS_REF"' \
    'export EXPECTED_BASE_BASH_LIBS_COMMIT="$(git -C vendor/base-bash-libs rev-parse HEAD)"' \
    'test "$(git -C vendor/base-bash-libs rev-parse HEAD)" = "$EXPECTED_BASE_BASH_LIBS_COMMIT"'; do
    grep -F "$quickstart_contract_text" docs/v2/quickstart.md > /dev/null || {
        printf 'The v2 quickstart must resolve and verify the current release tag.\n' >&2
        exit 1
    }
done
grep -F "base_bash_libs_ref='$current_release'" README.md > /dev/null || {
    printf 'README must use the current published release reference.\n' >&2
    exit 1
}
readme_current_release="$(sed -n 's/^`\(v[0-9][^`]*\)` is the current stable release.*$/\1/p' README.md | sed -n '1p')"
[[ "$readme_current_release" == "$current_release" ]] || {
    printf 'README must declare exactly one current stable release.\n' >&2
    exit 1
}
for readme_contract_text in \
    'git -C vendor/base-bash-libs checkout --detach "$base_bash_libs_ref"' \
    'base_bash_libs_commit="$(git -C vendor/base-bash-libs rev-parse HEAD)"' \
    'test "$(git -C vendor/base-bash-libs rev-parse HEAD)" = "$base_bash_libs_commit"'; do
    grep -F "$readme_contract_text" README.md > /dev/null || {
        printf 'README must resolve and verify the current release tag.\n' >&2
        exit 1
    }
done
if resolved_current_release="$(git rev-parse --verify "${current_release}^{commit}" 2> /dev/null)"; then
    printf 'Verified current-release tag locally: %s (%s).\n' "$current_release" \
        "$resolved_current_release" >&2
else
    printf 'Skipping current-release tag comparison: tag %s is unavailable in this checkout.\n' \
        "$current_release" >&2
fi
grep -F 'framework_launcher' docs/v2/quickstart.md > /dev/null || {
    printf "The v2 quickstart must use the verified launcher path.\n" >&2
    exit 1
}
grep -F 'init --profile standard --dir demo' docs/v2/quickstart.md > /dev/null || {
    printf "The v2 quickstart must use the launcher's --dir option.\n" >&2
    exit 1
}
if grep -F -- '--project demo' docs/v2/quickstart.md > /dev/null; then
    printf 'The v2 quickstart must not use the unsupported --project init option.\n' >&2
    exit 1
fi

grep -F 'v2/quickstart.md' docs/README.md > /dev/null || {
    printf 'Documentation link is missing: v2/quickstart.md\n' >&2
    exit 1
}
for demo_contract_url in \
    'https://github.com/basefoundry/base-bash-libs-demo/blob/v0.1.2/README.md' \
    'https://github.com/basefoundry/base-bash-libs-demo/blob/v0.1.2/docs/five-minute-tutorial.md' \
    'https://github.com/basefoundry/base-bash-libs-demo/blob/v0.1.2/docs/why-base-bash-libs.md' \
    'https://github.com/basefoundry/base-bash-libs-demo/blob/v0.1.2/docs/should-i-use-base-bash-libs.md'; do
    grep -R -F "$demo_contract_url" README.md docs/README.md docs/v2/quickstart.md > /dev/null || {
        printf 'Pinned Beacon learning-path link is missing: %s\n' "$demo_contract_url" >&2
        exit 1
    }
done
grep -F 'five-minute, offline Beacon application' README.md > /dev/null || {
    printf 'README must describe Beacon as a runnable learning path.\n' >&2
    exit 1
}
grep -F 'Bash 4.2.53+ application framework and standard library' README.md > /dev/null || {
    printf 'README must lead with the v2 application-framework value proposition.\n' >&2
    exit 1
}
for readme_application_contract_text in \
    'BEGIN README APPLICATION EXAMPLE' \
    'base_cli_model_init hello' \
    'base_app_config_define hello_policy name string' \
    'base_app_hook hello_policy cleanup' \
    'base_app_run hello_policy hello_execute' \
    'HELLO_NAME=Base'; do
    grep -F "$readme_application_contract_text" README.md > /dev/null || {
        printf 'README application example is missing: %s\n' "$readme_application_contract_text" >&2
        exit 1
    }
done
grep -F 'The libraries are layered from foundation to application.' README.md > /dev/null || {
    printf 'README must describe the layered library map.\n' >&2
    exit 1
}
grep -F '**Foundation:**' README.md > /dev/null || {
    printf 'README library map is missing the foundation layer.\n' >&2
    exit 1
}
grep -F '**Building blocks:**' README.md > /dev/null || {
    printf 'README library map is missing the building-block layer.\n' >&2
    exit 1
}
grep -F '**Application framework:**' README.md > /dev/null || {
    printf 'README library map is missing the application-framework layer.\n' >&2
    exit 1
}

readme_application_example="$(mktemp "${TMPDIR:-/tmp}/base-bash-readme-example.XXXXXX")" || exit 1
awk '
    /^<!-- BEGIN README APPLICATION EXAMPLE -->$/ { in_region = 1; next }
    /^<!-- END README APPLICATION EXAMPLE -->$/ { exit }
    in_region && /^```bash$/ { in_code = 1; next }
    in_region && in_code && /^```$/ { in_code = 0; next }
    in_region && in_code { print }
' README.md > "$readme_application_example" || exit 1
[[ -s "$readme_application_example" ]] || {
    printf 'README application example is empty.\n' >&2
    exit 1
}
readme_application_output="$(
    HELLO_NAME=Base BASE_BASH_LIBS_DIR="$repo_root/lib/bash" \
        "$repo_root/bin/base-bash" "$readme_application_example" greet
)" || {
    printf 'README application example did not execute.\n' >&2
    rm -f -- "$readme_application_example"
    exit 1
}
rm -f -- "$readme_application_example"
[[ "$readme_application_output" == 'hello=Base' ]] || {
    printf 'README application example produced unexpected output: %s\n' \
        "$readme_application_output" >&2
    exit 1
}
grep -F 'See a complete application' docs/v2/quickstart.md > /dev/null || {
    printf 'The v2 quickstart must link to the complete Beacon application.\n' >&2
    exit 1
}
grep -F 'released [v0.1.2]' docs/consumer-validation-status.md > /dev/null || {
    printf 'Consumer validation status must reference the current Beacon release.\n' >&2
    exit 1
}
grep -F 'v2/architecture.md' docs/README.md > /dev/null || {
    printf 'Documentation link is missing: v2/architecture.md\n' >&2
    exit 1
}
grep -F 'v2/migration-v1.4-to-v2.md' docs/README.md > /dev/null || {
    printf 'Documentation link is missing: v2/migration-v1.4-to-v2.md\n' >&2
    exit 1
}
grep -F 'ci-policy.md' docs/README.md > /dev/null || {
    printf 'Documentation link is missing: ci-policy.md\n' >&2
    exit 1
}
for link in SECURITY.md docs/support-policy.md docs/threat-model.md; do
    grep -R -F "$link" docs/README.md README.md > /dev/null || {
        printf 'Documentation link is missing: %s\n' "$link" >&2
        exit 1
    }
done

if grep -nF '\`' docs/support-matrix.md > /dev/null; then
    printf 'Support-matrix Markdown must not escape code-span backticks.\n' >&2
    exit 1
fi
if grep -nF '\\t' lib/bash/str/README.md lib/bash/app/README.md > /dev/null; then
    printf 'String and application docs must show one backslash in escape sequences.\n' >&2
    exit 1
fi
for module in process cli app; do
    grep -F -- "lib/bash/$module/lib_$module.sh" STANDARDS.md > /dev/null || {
        printf 'STANDARDS.md is missing the %s module.\n' "$module" >&2
        exit 1
    }
done
for link in pinned-consumption.md vendor-workflow.md single-file-distribution.md \
    integrations.md community.md versioning-policy.md release-process.md; do
    grep -F "$link" docs/README.md > /dev/null || {
        printf 'Documentation index is missing: %s\n' "$link" >&2
        exit 1
    }
done
grep -F 'Bash-4.2.53%2B' README.md > /dev/null || {
    printf 'README must advertise the 4.2.53 Bash floor.\n' >&2
    exit 1
}
grep -F 'Requires Bash 4.2.53+' README.md > /dev/null || {
    printf 'README must state the 4.2.53 Bash floor.\n' >&2
    exit 1
}

release_process=docs/release-process.md
for release_contract_text in \
    'lib/bash/base-bash-libs.release' \
    'commit=unknown' \
    'candidate rehearsal' \
    'real merged commit' \
    'scripts/release refs --version X.Y.Z' \
    'scripts/release-artifact verify-remote --version X.Y.Z --commit "$release_commit"'; do
    grep -F "$release_contract_text" "$release_process" > /dev/null || {
        printf 'Release-process documentation is missing the required contract text: %s\n' \
            "$release_contract_text" >&2
        exit 1
    }
done

# Rehearse the documented source-metadata transition in an isolated fixture.
# The checked-in commit and dirty-state fields remain provenance placeholders;
# only the version is advanced before the artifact builder creates its staged copy.
release_fixture="$(mktemp -d "${TMPDIR:-/tmp}/base-bash-release-docs.XXXXXX")" || exit 1
release_fixture_cleanup() { rm -rf -- "$release_fixture"; }
trap release_fixture_cleanup EXIT
cp VERSION "$release_fixture/VERSION" || exit 1
cp lib/bash/base-bash-libs.release "$release_fixture/base-bash-libs.release" || exit 1
printf '2.2.0\n' >| "$release_fixture/VERSION" || exit 1
awk -v candidate=2.2.0 '
    /^version=/ { print "version=" candidate; next }
    { print }
' "$release_fixture/base-bash-libs.release" >| "$release_fixture/base-bash-libs.release.next" || exit 1
mv -- "$release_fixture/base-bash-libs.release.next" "$release_fixture/base-bash-libs.release" || exit 1
[[ "$(< "$release_fixture/VERSION")" == "$(sed -n 's/^version=//p' "$release_fixture/base-bash-libs.release")" ]] || {
    printf 'Release-preparation metadata fixture did not align VERSION and embedded version.\n' >&2
    exit 1
}
grep -Fx 'commit=unknown' "$release_fixture/base-bash-libs.release" > /dev/null || {
    printf 'Release-preparation metadata fixture must preserve commit=unknown.\n' >&2
    exit 1
}
grep -Fx 'dirty_state=unknown' "$release_fixture/base-bash-libs.release" > /dev/null || {
    printf 'Release-preparation metadata fixture must preserve dirty_state=unknown.\n' >&2
    exit 1
}

printf 'Documentation contract passed.\n'
