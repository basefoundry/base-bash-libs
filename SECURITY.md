# Security policy

base-bash-libs is a sourceable Bash framework. Sourcing a library executes
code in the caller's process, so consumers must treat a library release and
every vendored copy as executable supply-chain input.

## Supported releases

The supported release line begins at the published `v2.0.0` GA. The former
`v1.4.0` line is now maintained only as a historical reference. Only the
latest supported v2 security release receives fixes. All 0.x releases and
pre-v2 1.x releases are historical and unsupported; the withdrawn July 2026
v2 tag/formula event was not a supported release. See
[`docs/versioning-policy.md`](docs/versioning-policy.md) for the full release
line and migration policy.

## Reporting a vulnerability

Please do not open a public issue for an unpatched vulnerability. Use GitHub's
private **Report a vulnerability** action on the
[Security tab](https://github.com/basefoundry/base-bash-libs/security) of this
repository. If private reporting is unavailable, contact the maintainers
through the address listed in the repository's GitHub security settings and
include `base-bash-libs security report` in the subject.

Include, when safe to share:

- the affected version or commit and the Bash/OS environment;
- a minimal reproducer, command line, or proof of concept;
- the impact, required privileges, and whether secrets or filesystem data are
  exposed; and
- any proposed mitigation or known workaround.

Encrypt sensitive material with the maintainers' current key from the GitHub
security contact page. Do not include real credentials, tokens, private data,
or destructive payloads in a report.

## Response and disclosure

Maintainers acknowledge private reports within 5 business days, provide an
initial severity and affected-version assessment within 10 business days, and
coordinate a fix, workaround, or explicit status update with the reporter.
Timelines can change when reproduction requires a third-party Bash, OS, or
package-manager response; the reporter will be told about that dependency.

We prefer coordinated disclosure after a fixed release or mitigation has been
available long enough for downstream consumers to update. The reporter and
maintainers will agree on a disclosure date, advisory wording, credit, and any
embargo. We will not publish identifying details without consent.

Security fixes follow the same immutable release rules as normal releases:
reviewed commits, a signed or attested release artifact when available, SBOM
and provenance metadata, and downstream notification for Base, Homebrew, and
verified vendor/bundle consumers. Incident corrections are recorded in the
changelog and the release notes.

## Scope and caller responsibilities

This policy covers the code and release artifacts in this repository. It does
not guarantee the safety of a caller's script, its input, external commands,
network services, package manager, shell startup files, or environment. Read
[`docs/threat-model.md`](docs/threat-model.md) and
[`docs/support-policy.md`](docs/support-policy.md) before embedding the
libraries in a privileged or unattended workflow.
