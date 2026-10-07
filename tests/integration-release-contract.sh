#!/usr/bin/env bash

# Networkless contract for the maintained integration pins.  This intentionally
# validates shape and immutable identities only; it never downloads optional
# third-party tools into Core or turns them into runtime dependencies.

integration_repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
integration_manifest="$integration_repo_root/integrations/compatibility.yaml"

integration_fail() {
    printf 'Integration release contract failed: %s\n' "$*" >&2
    exit 1
}

[[ -f "$integration_manifest" ]] || integration_fail "missing compatibility manifest"
grep -Fx 'schema_version: 1' "$integration_manifest" > /dev/null ||
    integration_fail 'schema version is not 1'
grep -Fx 'record_scope: historical-v2.0.0-ga-baseline' "$integration_manifest" > /dev/null ||
    integration_fail 'compatibility manifest must identify its historical baseline scope'
grep -Eq '^last_reviewed: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$integration_manifest" ||
    integration_fail 'compatibility manifest review date is missing or malformed'
grep -Fx 'framework_release_line: v2.0.0' "$integration_manifest" > /dev/null ||
    integration_fail 'framework release line is not v2.0.0'

for integration_name in bashly argc argbash bats-core shellcheck shfmt; do
    grep -E "^  - name: ${integration_name}$" "$integration_manifest" > /dev/null ||
        integration_fail "missing pin for ${integration_name}"
done

pin_count="$(grep -Ec '^    commit: [0-9a-f]{40}$' "$integration_manifest")"
[[ "$pin_count" == 6 ]] || integration_fail "expected 6 immutable pins, found $pin_count"

for integration_path in \
    integrations/bashly/example.sh \
    integrations/bats/base_bats_helper.bash \
    integrations/project-kit/.shellcheckrc \
    integrations/project-kit/shfmt.conf; do
    [[ -f "$integration_repo_root/$integration_path" ]] ||
        integration_fail "missing integration asset: $integration_path"
done

for channel in bpkg basher basalt; do
    grep -A2 -E "^  - name: ${channel}$" "$integration_repo_root/integrations/package-managers/registry.yaml" |
        grep -F 'status: deferred-until-maintained-update-path' > /dev/null ||
        integration_fail "package channel ${channel} must remain deferred until a maintained update path exists"
done

printf 'Integration release contract passed: pins=%s package_channels=3.\n' "$pin_count"
