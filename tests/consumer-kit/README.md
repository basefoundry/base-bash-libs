# Consumer conformance kit

The helper in `test_helper.bash` is intentionally framework-neutral. Consumer
projects can source it from BATS to get isolated temporary directories,
framework resolution, captured stdout/stderr/status, and a wrapper for the
non-mutating `base-bash check --project` contract.

The `fixtures/minimal-project` tree is a permanent offline fixture used to
exercise source-installed and vendored package layouts without network access.
