# Consumer-kit contribution path

The consumer kit is the smallest public path for testing an application or
integration against Base Bash. It lets a contributor exercise the framework
boundary without first learning the implementation of every library module.

## Start with these files

1. Read [`tests/consumer-kit/README.md`](../tests/consumer-kit/README.md) for
   the purpose and offline-fixture boundary.
2. Inspect [`test_helper.bash`](../tests/consumer-kit/test_helper.bash) for the
   framework-neutral helper functions.
3. Use the permanent
   [`minimal-project` fixture](../tests/consumer-kit/fixtures/minimal-project/README.md)
   as the smallest application layout.
4. Run the focused
   [`consumer_kit.bats`](../tests/consumer-kit/tests/consumer_kit.bats) suite:

   ```bash
   bats tests/consumer-kit/tests/consumer_kit.bats
   ```

The suite validates two useful consumer properties: the fixture can be
checked through the public `base-bash check --project` contract, and the
application's stdout remains separate from diagnostics. The helper also
provides `consumer_framework_dir`, `consumer_setup_tmpdir`, `consumer_run`,
`consumer_check`, and `consumer_assert_status` for a downstream BATS suite.
These are the consumer-kit entry points; do not depend on private library
functions or test implementation details.

## Consumer and framework responsibilities

The consumer owns its application files, command behavior, configuration,
expected output, and the version or artifact pin it is evaluating. The
framework owns the documented launcher, library APIs, lifecycle behavior, and
the non-mutating `check --project` contract. A consumer test should assert the
integration boundary it needs, not duplicate the framework's complete
internal suite.

For a source checkout, the helper resolves the framework from the current
repository's `lib/bash` directory unless `BASE_BASH_LIBS_DIR` is explicitly
provided. This is useful while developing an integration, but it is moving
source and is not release evidence. For a release, vendored tree, Homebrew
installation, or bundle, validate one immutable package root and record its
full commit, version, checksum, and provenance as described in
[pinned consumption](pinned-consumption.md). Do not mix modules from a moving
checkout with an immutable artifact.

## Report a reproducible failure

Include the smallest failing command and these facts:

```text
Base Bash version: <installed or artifact version>
Bash: <bash --version first line>
OS: <uname -a or platform equivalent>
Framework source: <full commit, or release version and checksum>
Command: bats tests/consumer-kit/tests/consumer_kit.bats
Exit status: <number>
```

Attach the relevant stdout and stderr separately, with tokens, credentials,
private paths, and unrelated environment values removed. If the failure is
specific to a vendored or bundled artifact, include the artifact verification
result and do not silently retry against the moving default branch. Use the
[community guide](community.md) for ordinary participation and
[`SECURITY.md`](../SECURITY.md) for security-sensitive reports.

## Evidence boundary

The checked-in fixture is a first-party compatibility fixture. It demonstrates
that the consumer path works and gives contributors a reproducible starting
point; it is not independent adoption evidence or a user case study. New
external integrations should document their own pinned input, focused test,
and observed result before being listed as independent validation. The full
project gate remains [`tests/validate.sh`](../tests/validate.sh); this focused
suite does not replace it.
