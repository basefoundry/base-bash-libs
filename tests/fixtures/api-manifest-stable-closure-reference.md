# Base Bash API Reference

> This file is generated from `base_api_manifest.yaml`; edit the manifest or the module READMEs instead.

## Contract

- Manifest schema: 1
- API version: 2.0.0
- Minimum Bash: 4.2

Every module remains a single sourceable file. Signatures, inputs, outputs,
statuses, and side effects are normative in the linked module README and
[API charter](v2-api-contract.md).

- Public functions: `base_`
- Globals: `BASE_BASH_LIBS_`
- Internals: `__base_bash_libs_`

## Modules

### `process`

- Kind: `sourceable-library`
- Source: [`lib/bash/process/lib_process.sh`](../lib/bash/process/lib_process.sh)
- Documentation: [`lib/bash/process/README.md`](../lib/bash/process/README.md)
- Tests: [`lib/bash/process/tests/lib_process.bats`](../lib/bash/process/tests/lib_process.bats)
- Dependencies: `none`
- Optional commands: `ps,rm,sleep`
- Stability: `stable`; since `2.0.0`; deprecated: `false`
- Inputs: documented per symbol in the module README and API charter
- Outputs: documented per symbol; no caller-owned outputs
- Statuses: usage and contract errors return 2; a false owner relationship returns 1
- Side effects: documented per symbol; sourcing is passive

#### Public symbols

- `base_process_owner_alive` — signature: see [`lib/bash/process/README.md`](../lib/bash/process/README.md).

### `str`

- Kind: `sourceable-library`
- Source: [`lib/bash/str/lib_str.sh`](../lib/bash/str/lib_str.sh)
- Documentation: [`lib/bash/str/README.md`](../lib/bash/str/README.md)
- Tests: [`lib/bash/str/tests/lib_str.bats`](../lib/bash/str/tests/lib_str.bats)
- Dependencies: `process`
- Optional commands: `none`
- Stability: `stable`; since `2.0.0`; deprecated: `false`
- Inputs: documented per symbol in the module README and API charter
- Outputs: documented per symbol; named outputs are caller-owned
- Statuses: recoverable failures return nonzero statuses
- Side effects: documented per symbol; sourcing is passive

#### Public symbols

- `base_str_contains` — signature: see [`lib/bash/str/README.md`](../lib/bash/str/README.md).
- `base_str_ends_with` — signature: see [`lib/bash/str/README.md`](../lib/bash/str/README.md).
- `base_str_join` — signature: see [`lib/bash/str/README.md`](../lib/bash/str/README.md).
- `base_str_lower` — signature: see [`lib/bash/str/README.md`](../lib/bash/str/README.md).
- `base_str_ltrim` — signature: see [`lib/bash/str/README.md`](../lib/bash/str/README.md).
- `base_str_rtrim` — signature: see [`lib/bash/str/README.md`](../lib/bash/str/README.md).
- `base_str_split` — signature: see [`lib/bash/str/README.md`](../lib/bash/str/README.md).
- `base_str_starts_with` — signature: see [`lib/bash/str/README.md`](../lib/bash/str/README.md).
- `base_str_trim` — signature: see [`lib/bash/str/README.md`](../lib/bash/str/README.md).
- `base_str_upper` — signature: see [`lib/bash/str/README.md`](../lib/bash/str/README.md).

