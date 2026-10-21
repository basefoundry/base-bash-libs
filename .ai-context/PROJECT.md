# Base Bash

`base-bash-libs` is an independently consumable Bash application framework and
standard library. It provides checked execution, logging, cleanup, structured
CLIs, typed configuration, and reusable shell helpers. Its consumers include
Base, standalone scripts, and the separate Beacon reference application.

Use it where Bash is an intentional runtime constraint and shared application
infrastructure is useful. It does not require the Base workspace runtime and
does not own an application's domain policy. Homebrew installation, vendored
release bundles, source checkouts, and submodules are supported consumption paths.
The documented minimum is Bash 4.2.53; macOS system Bash is insufficient.

The public API manifest and versioning policy define stability. The `process`
module is preview functionality; do not infer stable status merely because it
ships in a release. Use VERSION and immutable release evidence for exact package
identity instead of treating this summary as a current-release registry.

Sources: [README](../README.md), [API contract](../docs/v2-api-contract.md),
[API manifest](../base_api_manifest.yaml), and
[support matrix](../docs/support-matrix.md).
