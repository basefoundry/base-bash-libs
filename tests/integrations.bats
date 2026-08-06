#!/usr/bin/env bats

setup() {
    repo_root="$(cd "${BATS_TEST_DIRNAME}/.." && pwd -P)"
}

@test "Bashly adapter preserves the v2 argv boundary" {
    run bash "$repo_root/integrations/bashly/example.sh" candidate

    [ "$status" -eq 0 ]
    [[ "$output" == *"release=candidate"* ]]
}

@test "integration recipes remain optional and package registry stays pre-GA" {
    run grep -F 'status: planned-after-v2-ga' "$repo_root/integrations/package-managers/registry.yaml"

    [ "$status" -eq 0 ]
    [ "$(grep -c 'status: planned-after-v2-ga' "$repo_root/integrations/package-managers/registry.yaml")" -eq 3 ]
}

@test "project kit declares Bash-aware static-analysis policy" {
    grep -F 'shell=bash' "$repo_root/integrations/project-kit/.shellcheckrc"
    grep -F 'language-dialect = bash' "$repo_root/integrations/project-kit/shfmt.conf"
}

@test "integration release contract keeps immutable pins and deferred channels" {
    run "$repo_root/tests/integration-release-contract.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"pins=6 package_channels=3"* ]]
}
