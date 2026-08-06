# Installer reference application

`base-installer` models a verified installer/updater. It accepts typed path and
secret configuration, keeps stdout machine-readable, redacts token state, and
preserves status through cleanup.

```bash
BASE_BASH_LIBS_DIR="$PWD/lib/bash" "$PWD/bin/base-bash" \
  examples/reference-apps/installer/bin/app status
BASE_BASH_LIBS_DIR="$PWD/lib/bash" BASE_REFERENCE_INSTALL_TARGET=/tmp/demo \
  "$PWD/bin/base-bash" examples/reference-apps/installer/bin/app install --dry-run
```

The BATS suite covers missing state, idempotent install/update, dry-run, and
unknown-command failures.
