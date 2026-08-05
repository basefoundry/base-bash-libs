#!/usr/bin/env bats
@test "fixture runs" {
    run "$BATS_TEST_DIRNAME/../bin/app"
    [ "$status" -eq 0 ]
    [ "$output" = "fixture=ok" ]
}
