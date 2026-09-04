# v2 quickstart

This path is designed for a new consumer. It uses one immutable, verified
release reference and exercises initialization, a generated application,
checks, tests, and a deterministic bundle.

## 1. Select a verified release

Use the published `v2.0.0` tag and its verified commit. The reference is
intentionally required rather than defaulting to a moving branch:

```bash
export BASE_BASH_LIBS_REF='v2.0.0'
export BASE_BASH_LIBS_COMMIT='b4243765726c133499feeabdc50154f99c0fec12'
mkdir -p vendor
git clone https://github.com/basefoundry/base-bash-libs.git vendor/base-bash-libs
git -C vendor/base-bash-libs fetch --tags origin "$BASE_BASH_LIBS_REF"
git -C vendor/base-bash-libs checkout --detach "$BASE_BASH_LIBS_REF"
test "$(git -C vendor/base-bash-libs rev-parse HEAD)" = "$BASE_BASH_LIBS_COMMIT"
```

Do not replace the ref with `main`, a short SHA, or an automatically generated
archive URL. Verify the published checksum asset before distributing a
consumer application.

The preview `process` module is not present in this v2.0.0 checkout. Follow
the next release's documentation after a release containing that module is
published; do not import it from this pinned tree.

## 2. Generate and run an application

The launcher creates a deterministic scaffold. The application module is one
physical file, as required by `STANDARDS.md`:

```bash
mkdir -p demo
vendor/base-bash-libs/bin/base-bash init --profile standard --dir demo
cd demo
BASE_BASH_LIBS_DIR="../vendor/base-bash-libs/lib/bash" ./bin/app --help
BASE_BASH_LIBS_DIR="../vendor/base-bash-libs/lib/bash" ./bin/app status
BASE_BASH_LIBS_DIR="../vendor/base-bash-libs/lib/bash" ./bin/app run --dry-run
```

The generated app demonstrates declarative commands, typed data-only config,
redacted diagnostics, dry-run behavior, lifecycle hooks, and status-preserving
cleanup. It does not evaluate configuration as shell code.

`BASE_BASH_LIBS_PIN` records the exact framework commit when initialization
runs from a clean checkout or verified release artifact. A dirty checkout or a
source tree without verifiable identity is recorded as
`verification=development-unverified`; do not release the generated
application until that record has been regenerated from a clean, verified
framework source.

## 3. Check, test, and bundle

```bash
BASE_BASH_LIBS_DIR="../vendor/base-bash-libs/lib/bash" \
  ../vendor/base-bash-libs/bin/base-bash check --project .
./tests/run.sh
BASE_BASH_LIBS_DIR="../vendor/base-bash-libs/lib/bash" \
  ../vendor/base-bash-libs/scripts/library-bundle bundle /tmp/base-bash-bundle
../vendor/base-bash-libs/scripts/library-bundle verify /tmp/base-bash-bundle
```

The complete process is also available offline in the
[`tests/consumer-kit`](../../tests/consumer-kit/README.md) fixture.
