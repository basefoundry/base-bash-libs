#!/usr/bin/env bats

setup() {
    REPO_ROOT="$BATS_TEST_DIRNAME/.."
    OUTPUT="$BATS_TEST_TMPDIR/row.json"
    COMMIT=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
}

@test "release BOM row records immutable release identity and API contract" {
    run "$REPO_ROOT/scripts/release-bom-row" \
        --version 2.1.0 \
        --commit "$COMMIT" \
        --platform macos-14 \
        --platform ubuntu-24.04 \
        --evidence run://base-bash-libs/validate \
        --output "$OUTPUT"

    [ "$status" -eq 0 ]
    run python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["tag"] == "v2.1.0"; assert d["commit"] == sys.argv[2]; assert d["api_schema_version"] == "base-bash-libs-api@2.0.0"; assert d["required"] is True; assert d["result"] == "passed"' "$OUTPUT" "$COMMIT"
    [ "$status" -eq 0 ]
}

@test "release BOM row rejects abbreviated commits" {
    run "$REPO_ROOT/scripts/release-bom-row" \
        --version 2.1.0 \
        --commit deadbeef \
        --platform ubuntu-24.04 \
        --evidence run://base-bash-libs/validate \
        --output "$OUTPUT"

    [ "$status" -eq 2 ]
    [[ "$output" == *"lowercase full 40-character SHA"* ]]
}
