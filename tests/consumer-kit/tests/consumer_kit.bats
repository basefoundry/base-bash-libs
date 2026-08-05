#!/usr/bin/env bats

load ../test_helper.bash

setup() {
    consumer_setup_tmpdir "$BATS_TEST_TMPDIR"
}

@test "fixture is compatible with the installed framework" {
    local fixture
    fixture="$(cd "$BATS_TEST_DIRNAME/../fixtures/minimal-project" && pwd -P)"
    run consumer_check "$fixture" json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"check":"framework-pin"'* ]]
}

@test "fixture keeps stdout data separate from diagnostics" {
    local fixture
    fixture="$(cd "$BATS_TEST_DIRNAME/../fixtures/minimal-project" && pwd -P)"
    run consumer_run "$fixture"
    [ "$status" -eq 0 ]
    [ "$output" = "fixture=ok" ]
}
