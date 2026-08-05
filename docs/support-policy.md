# Stability, support, and release policy

This document is the operational contract for the framework. The automated
compatibility and release checks in `tests/compatibility-matrix.sh`,
`tests/release-invariants.sh`, and `tests/validate.sh` are the source of truth
for claims that can be tested. A claim below marked **caller responsibility**
is deliberately not a guarantee supplied by a library.

## Stable API and release lines

- SemVer compatibility, deprecation windows, and supported-release promises
  begin with `v2.0.0` GA.
- `v2.x` may add public helpers and fixes without breaking documented v2
  behavior. A breaking stable public API change requires `v3.0.0` or later.
- 0.x and 1.x releases, including `v1.4.0`, are historical and unsupported
  after v2 GA. There was no supported v2 release in the withdrawn July 2026
  event; its tag and Homebrew formula are documented in the versioning policy
  only so consumers can identify stale caches.
- v2 prereleases may break without compatibility shims. They are for testing,
  not a production support promise.
- Deprecations are documented in the changelog and API reference. A supported
  v2 helper is not removed or made incompatible during 2.x without a security
  exception or a published migration note.

## Runtime support matrix

| Area | Guarantee | Evidence or caller responsibility |
| --- | --- | --- |
| Bash | Bash 4.2.53 or newer; current Bash is exercised in CI | `tests/compatibility-matrix.sh`, `tests/bash-42-*.sh`; caller must use Bash, not `sh`/dash |
| macOS | Homebrew Bash is supported; Apple `/bin/bash` 3.2 is not | macOS CI; caller installs and selects a supported Bash |
| Linux | Ubuntu/glibc and Alpine/musl paths are tested where runners/tools exist | compatibility matrix and release workflow; caller supplies the OS runtime |
| BSD/other Unix | Best-effort source compatibility, not a release guarantee | caller validates the matrix on the target OS |
| Userland | Only documented Bash builtins and explicitly listed external tools are assumed | manifests, tests, and command-readiness helpers; caller provisions optional tools |
| Locale | Results requiring byte, character, or sort semantics are locale-sensitive | caller sets `LC_ALL`/`LANG` when deterministic locale behavior is required |
| Filesystem | Helpers operate on accessible paths and preserve quoted path boundaries | file tests and race-resistant cleanup checks; caller controls permissions, mounts, symlinks, and concurrent writers |
| Privilege | No privilege escalation and no implicit `sudo` | tests and code review; caller runs with least privilege and owns authorization |
| TTY | Non-interactive execution is supported when prompts are disabled or answered by policy | prompt and launcher tests; caller supplies a TTY or explicit prompt policy when needed |
| External commands | Failures and statuses are surfaced; no guarantee is made about a command's semantics or availability | `base_std_run`, command probes, and caller-owned dependency checks |

Strict-option behavior is part of the API contract: libraries do not enable
`set -e`, `set -u`, or `pipefail` for callers, and must remain usable when a
caller has selected those options. The option matrix is enforced by CI.

## Release, artifact, and incident controls

Every release must:

1. use an immutable `vMAJOR.MINOR.PATCH` tag (or an explicitly identified
   prerelease tag) created from the reviewed release commit;
2. publish a canonical source/bundle artifact with a SHA-256 checksum and
   machine-readable release metadata;
3. publish an SBOM and provenance/attestation; signatures are preferred and
   become required when the configured release service supports them;
4. pass the compatibility, API-manifest, deterministic-bundle, action/image
   pinning, and security checks before publication; and
5. update Homebrew, Base, Base Demo, vendor, and bundle consumers only after
   the exact asset and checksum have been verified.

Dependencies and GitHub Actions are updated through reviewed pull requests.
Security updates may use an expedited review, but still require a recorded
commit, test evidence, and release note. A compromised or withdrawn artifact
is never silently retagged: revoke or supersede it, document the incident,
publish a corrected immutable version, and notify downstream consumers.

## Evidence map

The following mapping keeps prose from drifting away from automation:

| Contract | Automated evidence |
| --- | --- |
| API names and module boundaries | `base_api_manifest.yaml`, `scripts/api-manifest`, `tests/api-manifest.bats` |
| Bash/OS/strict-option support | `tests/compatibility-matrix.sh`, `tests/bash-42-*.sh`, `tests/bash-option-contract.sh`, CI matrix |
| Release metadata and SemVer | `tests/validate.sh`, `tests/release.bats`, `scripts/release` |
| Bundle reproducibility and artifact identity | `tests/release-invariants.sh`, `tests/library-bundle.bats`, `docs/pinned-consumption.md` |
| Namespace and migration contract | `tests/namespace-contract.bats`, `docs/v2-api-contract.md`, `docs/v2-symbol-map.md` |
| Security and caller boundaries | `SECURITY.md`, `docs/threat-model.md`, this document, code review |

If an environment or guarantee is not covered by that evidence, it is a caller
responsibility until a new test and support-matrix entry are added.
