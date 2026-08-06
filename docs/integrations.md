# Official integration recipes

Integrations are optional build/test boundaries. Core remains Bash-only and
does not install or invoke a generator, package manager, linter, or formatter.
Every recipe below preserves the v2 initialization, `base_` namespace,
single-file application module, lifecycle, status, and immutable-artifact
contracts.

## Bashly

Use [`integrations/bashly/base_bashly.sh`](../integrations/bashly/base_bashly.sh)
from the Bashly-generated entrypoint after sourcing `lib_std.sh` and importing
`cli/lib_cli.sh`:

```bash
source "$BASE_BASH_LIBS_DIR/std/lib_std.sh"
base_std_import cli/lib_cli.sh
source integrations/bashly/base_bashly.sh
declare -a app_args=()
base_bashly_init app_args
base_bashly_run app -- "${app_args[@]}"
```

Bashly owns generated help/build output. Base Bash owns initialization, command
boundaries, lifecycle hooks, statuses, and bundling. Do not parse Bashly's
generated variables as configuration or source generated text from input.

## Argc and Argbash

Both generators can remain the argument front end. Emit a `--` boundary and
hand the resulting argv to `base_init`/`base_cli_run`; do not let a generator
install a second global trap or reinterpret `--` after the handoff:

```bash
declare -a app_args=("$@")
base_init app_args --source "${BASH_SOURCE[0]}" -- "${app_args[@]}"
base_cli_run app -- "${app_args[@]}"
```

Generated help belongs to the generator only until the application declares a
v2 command model. If both are exposed, document which command owns each output
and test the exact argv boundary.

## Bats, ShellCheck, and shfmt

Load [`integrations/bats/base_bats_helper.bash`](../integrations/bats/base_bats_helper.bash)
from a consumer's `test_helper.bash`. The repository's consumer kit remains the
reference for project conformance. Copy the project-kit `.shellcheckrc`,
`.editorconfig`, and `shfmt.conf` as policy starting points; invoke the tools
in CI rather than making them runtime dependencies.

## Package channels

`integrations/package-managers/registry.yaml` is an intentionally conservative
registry. bpkg, Basher, and Basalt entries remain `planned-after-v2-ga` until an
immutable v2 asset, checksum, provenance, and a maintained update path exist.
No package-manager URL in this repository is presented as an official install
source before those gates pass.

## Compatibility table

| Integration | Supported boundary | Mandatory dependency | Verification |
| --- | --- | --- | --- |
| Bashly | generated argv → `base_bashly_init`/`base_bashly_run` | none at runtime | adapter example + shellcheck |
| Argc | generated argv with one `--` handoff | none at runtime | recipe contract test |
| Argbash | generated argv with one `--` handoff | none at runtime | recipe contract test |
| Bats | consumer helper and project kit | Bats in test environment | consumer-kit BATS suite |
| ShellCheck | Bash dialect, repository warning/error policy | ShellCheck in CI | `tests/validate.sh` |
| shfmt | opt-in Bash formatting profile | shfmt in CI | project-kit config |
| bpkg/Basher/Basalt | verified artifact metadata only | package manager at install time | registry gate after v2 GA |
