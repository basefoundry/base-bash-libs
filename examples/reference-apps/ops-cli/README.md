# Operations CLI reference application

`base-ops` is a multi-command operations workflow with status, sync, diagnose,
and completion commands. Sync is dry-run safe, GitHub/network access is not
implicit, and optional tools are reported without becoming dependencies.

```bash
BASE_BASH_LIBS_DIR="$PWD/lib/bash" "$PWD/bin/base-bash" \
  examples/reference-apps/ops-cli/bin/app status
BASE_BASH_LIBS_DIR="$PWD/lib/bash" "$PWD/bin/base-bash" \
  examples/reference-apps/ops-cli/bin/app sync --dry-run
```

The BATS suite covers completion, dry-run synchronization, diagnostics, and
status output.
