# v2 architecture and production guide

## Architecture

The framework has a passive stdlib foundation and single-file modules. Source
the stdlib, call `base_init` once with the application argv, then import only
the modules the application uses. Imports are package-relative and guarded;
the caller's working directory is not a dependency.

| Layer | Responsibility | Start here |
| --- | --- | --- |
| launcher | Bash selection, package identity, checks, scaffold, script boundary | [`bin/base-bash`](../../bin/base-bash) |
| std | logging, statuses, command execution, PATH, prompts, temp/cleanup, imports | [`lib/bash/std/README.md`](../../lib/bash/std/README.md) |
| process | reusable owner-guardian and process-supervision primitives layered on std | [`lib/bash/process/README.md`](../../lib/bash/process/README.md) |
| modules | file, Git, GitHub, string, argument, list helpers | [`base_api_manifest.yaml`](../../base_api_manifest.yaml) |
| application | CLI schema, config, standard options, lifecycle and dispatch | generated `lib/app.sh` and `docs/v2-api-contract.md` |

## Execution and initialization

Sourcing is passive: it does not parse application arguments, change strict
options, or install application traps. `base_init` publishes the filtered
argv/context and is idempotent. `base_cli_run` parses the declared command
schema; application code receives validated values rather than raw shell text.

## Modules and imports

Each public sourceable library remains a single file. Use
`base_std_import module/lib_module.sh`; never source a library by a path derived
from untrusted input. The [API manifest](../../base_api_manifest.yaml) is the
machine-readable module graph and the generated reference is checked in CI.

## Application contract

- **Command schemas:** declare commands, flags, scalar values, and repeatable
  values before dispatch; unknown options are errors.
- **Configuration:** define typed keys with defaults and environment/file
  precedence. Files are data (`key=value`), never executable shell.
- **Lifecycle:** register cleanup hooks in LIFO order. A shared EXIT dispatcher
  runs each hook once and preserves the application's original status.
- **Outputs/statuses:** stdout is data; diagnostics and logs use stderr. A
  recoverable helper returns a documented nonzero status; process termination is
  reserved for the launcher boundary.
- **Observability:** use categories and levels, redact sensitive values, and
  make terminal color/TTY behavior explicit.
- **Signals:** applications may add signal policy through the lifecycle API;
  they must not replace the framework's dispatcher without preserving status
  and cleanup semantics.

## Delivery

Run the generated BATS suite and `base-bash check --project` in CI. Keep the
framework pinned by tag plus full commit, vendor only verified assets, and use
[`docs/single-file-distribution.md`](../single-file-distribution.md) for a
deterministic bundle. Release tags, checksums, SBOM/provenance, and downstream
cutover follow [`docs/release-process.md`](../release-process.md) and the
[support policy](../support-policy.md).

## Platform notes

The supported minimum is Bash 4.2.53. macOS `/bin/bash` 3.2 is outside the
contract; install Homebrew Bash and use `base-bash` or a Bash 4.2+ shebang.
Ubuntu/glibc and Alpine/musl paths are exercised where the release workflow has
the required runner/container. BSD and other userlands are advisory until a
consumer runs the compatibility matrix there. Locale, filesystem permissions,
TTY availability, and optional external commands remain caller choices.
