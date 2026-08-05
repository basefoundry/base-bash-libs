# Release helper reference application

`base-release-helper` separates non-mutating check/plan operations from the
explicit GitHub publish boundary. Tokens are marked sensitive and the publish
path requires an artifact. Rollback output points to a previous immutable
release rather than retagging.

```bash
BASE_BASH_LIBS_DIR="$PWD/lib/bash" "$PWD/bin/base-bash" \
  examples/reference-apps/release-helper/bin/app plan
```

The BATS suite never contacts GitHub; it covers plan, missing-artifact failure,
and rollback behavior.
