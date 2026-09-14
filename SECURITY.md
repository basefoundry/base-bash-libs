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

Please do not open a public issue for an unpatched vulnerability. Use the
repository's enabled GitHub private **Report a vulnerability** action from the
[Security tab](https://github.com/basefoundry/base-bash-libs/security). This is
the primary intake channel and creates a private security advisory for the
reporter and maintainers.

If the GitHub action is unavailable, email
[codeforester@gmail.com](mailto:codeforester@gmail.com?subject=base-bash-libs%20security%20report)
with `base-bash-libs security report` in the subject. Use that fallback only to
request a private reporting channel: do not include vulnerability details,
credentials, private data, or sensitive attachments until a secure channel has
been confirmed. No public encryption key is required for the supported GitHub
private-reporting flow; maintainers will provide the appropriate secure path
for any fallback report.

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

The primary triage owner is `codeforester`, the repository maintainer. GitHub
repository administrators and organization security managers are the
escalation roles for an unassigned, unavailable, or time-sensitive report; no
second maintainer is implied by this policy. If no acknowledgment arrives
within 5 business days, reply to the fallback address above with the same
subject and ask for escalation.

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
