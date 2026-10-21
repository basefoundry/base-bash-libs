# Architecture

Each public module is one sourceable file under `lib/bash/<module>/lib_<module>.sh`.
`std` provides initialization, logging, checked commands, imports, filesystem
helpers, and cleanup registration. `arg`, `str`, `list`, `file`, `git`, and `gh`
add composable utilities. `cli` declares command models; `app` supplies typed
configuration and application lifecycle policy. `process` offers preview
supervision primitives rather than a second stable runner API.

Sourcing stdlib is passive. Standalone consumers initialize through `base_init`;
`bin/base-bash` preloads stdlib, initializes once, sources the application, and
calls its `main`. Package-relative imports use `base_std_import` or the launcher's
import helper. Public functions use `base_<module>_...`; framework-owned state
uses `BASE_BASH_LIBS_...`. Applications retain ownership of their command and
configuration semantics.

Keep existing single-file library boundaries. Production libraries use explicit
status checks rather than `set -e`, `set -u`, or `pipefail`. Logs belong on stderr;
stdout remains available for command data. Release bundles, API checks, and
consumer fixtures establish compatibility independently of any one application.

Sources: [module map](../lib/bash/README.md), [stdlib contract](../lib/bash/std/README.md),
[standards](../STANDARDS.md), and [launcher](../bin/base-bash).
