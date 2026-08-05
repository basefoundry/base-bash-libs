# Migrate from v1.4.0 to v2

This is a clean break. There is no v1.5.0 compatibility release and no legacy
shim layer. Make the migration in a branch, run the consumer conformance kit,
and update the pinned artifact and tests together.

## Mechanical changes

1. Require Bash 4.2.53+ and remediate macOS by installing Homebrew Bash.
2. Replace generic public symbols with the `base_` namespace using
   [`scripts/migrate-v2-symbols`](../../scripts/migrate-v2-symbols), then review
   every result. The tool never rewrites Python, documentation prose, or
   caller-owned meanings implicitly.
3. Source `lib/bash/std/lib_std.sh`, call `base_init` explicitly, and import
   modules with `base_std_import`.
4. Replace direct `exit`-based helpers with the v2 status contract; keep stdout
   for data and stderr for diagnostics.
5. Convert cleanup to LIFO lifecycle hooks and preserve the application status
   through the shared dispatcher.
6. Pin the v2 RC/GA tag to its full commit and verify the checksum before
   vendoring or bundling.

## Behavior to re-test

Run the consumer's own tests plus:

```bash
scripts/migrate-v2-symbols --check path/to/script.sh
base-bash check --project path/to/project --format json
tests/compatibility-matrix.sh
scripts/library-bundle check
```

Do not add a `base_bash_libs_*` compatibility alias, a `bl_*` alternate
namespace, or an unpinned `main` checkout. The stable v2 namespace is
`base_`/`BASE_`; the former API is historical.
