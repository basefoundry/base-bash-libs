# Reference applications

These three applications are production-shaped fixtures for the v2 framework.
They intentionally remain small enough to audit and each application policy is
one physical `lib/app.sh` file.

| Application | Workflow exercised |
| --- | --- |
| [`installer`](installer/) | verified install/update/rollback, typed paths, redaction, idempotent file state, dry-run and cleanup |
| [`release-helper`](release-helper/) | CI/release planning, Git inspection, explicit GitHub mutation boundary, sensitive token handling, rollback guidance |
| [`ops-cli`](ops-cli/) | multi-command operations, completion, Git synchronization, optional tool probes, diagnostics, signals/cleanup |

Run an application through the repository launcher so the framework path is
explicit:

```bash
BASE_BASH_LIBS_DIR="$PWD/lib/bash" \
  "$PWD/bin/base-bash" examples/reference-apps/ops-cli/bin/app status
```

Each fixture has failure-path BATS coverage. The apps use only supported public
APIs; optional network and GitHub operations are never performed by tests.
Release inputs remain immutable pins and are verified by the repository bundle
and vendor checks.
