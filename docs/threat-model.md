# Threat model

base-bash-libs is loaded into a caller's Bash process. The trust boundary is
therefore the source path and release artifact, the caller's environment and
arguments, and every command or file operation performed after sourcing. This
model describes the threats the framework reduces and the boundaries it does
not control.

## Assets and trust boundaries

- caller secrets, environment variables, arguments, files, repositories, and
  generated output;
- the Bash process and its exit status, traps, signal state, and logs;
- vendored, bundled, Homebrew, and source-checkout release artifacts;
- GitHub/network credentials and remote repositories used by optional helpers.

The framework trusts the maintainer-reviewed artifact, the Bash interpreter,
the caller's selected working directory, and external commands. A sourceable
library cannot sandbox itself from the caller or undo permissions already
granted to the process.

## Threats and mitigations

| Surface | Threat | Framework mitigation | Caller responsibility |
| --- | --- | --- | --- |
| Sourced code/imports | An untrusted or stale path executes code in-process | package-relative imports, explicit paths, API manifests, immutable-consumption guidance | pin a reviewed commit/artifact; never source an untrusted default branch |
| `argv` and parsing | Spaces, empty values, option confusion, or accidental globbing alter behavior | array-based argument helpers, exact option parsing, quoted path/argv contracts | validate application-specific input and avoid `eval` |
| Configuration | Environment/config values leak secrets or silently change behavior | typed config parsing, precedence/provenance, redaction, opt-in standard options | classify secrets, set least-privilege permissions, and review caller config |
| Paths/symlinks | Traversal, symlink replacement, or wrong working directory changes a target | absolute-root helpers, checked paths, explicit cleanup ownership, no implicit `sudo` | control directory permissions, resolve security-sensitive symlinks, and avoid shared writable trees |
| Temporary files/deletion | Predictable temp names or broad deletion destroys data | managed temp paths, idempotent cleanup, marker-scoped edits, status-preserving traps | keep temp roots private and never pass untrusted deletion targets |
| Subprocesses | Injection or lost exit status from external commands | `base_std_run`, argv arrays, explicit command readiness, propagated statuses | do not concatenate untrusted shell syntax or assume an external command is safe |
| Logs/secrets | Tokens or credentials appear in diagnostics | redaction and safe logging helpers; no secret persistence by default | mark sensitive values, avoid `set -x`, and secure log destinations |
| Signals/lifecycle | Cleanup masks the real status or runs twice | LIFO hooks, shared EXIT dispatcher, idempotent teardown, signal-aware app lifecycle | make application cleanup idempotent and avoid replacing library traps blindly |
| Network/retries | Retry storms, credential forwarding, or ambiguous remote state | bounded retry helpers, timeout/status contracts, checked `gh`/Git wrappers | configure network policy, scopes, backoff limits, and remote trust |
| Vendoring/bundles | Tampered or non-reproducible copies enter production | deterministic bundle checks, release metadata, checksums, SBOM/provenance gates | verify the exact checksum/attestation before installation |
| Release supply chain | Mutable tags, unpinned actions, or compromised tooling publishes bad code | pinned workflows/images/tools, immutable release process, artifact preflight | protect maintainer credentials and verify downstream pins |

## Security invariants

The libraries must not enable strict mode in the caller, mutate unrelated global
state, log secret values by default, escalate privileges, or silently convert a
failed external command into success. These invariants are tested where
possible and reviewed where Bash cannot provide a complete isolation guarantee.

## Residual risk and reporting

Race conditions in a hostile shared filesystem, malicious Bash startup files,
compromised interpreters or external commands, and malicious code deliberately
sourced by the caller remain out of scope. Report suspected violations using
[`SECURITY.md`](../SECURITY.md), with a minimal reproducer and the exact commit
or artifact identity.
