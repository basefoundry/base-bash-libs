# Consumer validation status

Last validated: 2026-08-15

This is an internal readiness ledger for the #239 adoption work. It records
what can be reproduced from the current local checkouts; it is not a public
adoption claim. Independent users belong in the permissioned
[validation register](who-uses-base-bash.md) only after a downstream owner
has approved publication.

## Framework reference

The release gate used the immutable `base-bash-libs` v2.0.0 GA at merge commit
`b4243765726c133499feeabdc50154f99c0fec12`. The
[v2.0.0 release](https://github.com/basefoundry/base-bash-libs/releases/tag/v2.0.0)
archive, SHA256SUMS, SPDX SBOM, and provenance assets were downloaded and
verified. The canonical archive SHA256 is
`73d6f92fab8f1a8ded7f3b4312ebbe51aa8ec0c16eacf18c2d8fa23fb5664333`.

## Consumer matrix

| Checkout | Relationship | Reference | Deployment exercised | Result | Classification |
| --- | --- | --- | --- | --- | --- |
| Base | First-party direct consumer | published [v1.8.0](https://github.com/basefoundry/base/releases/tag/v1.8.0), commit `26b9af5` | CI and source-checkout workflows pin GA commit `b424376` (v2.0.0) | PR [#1936](https://github.com/basefoundry/base/pull/1936) passed Python/pylint, integration, security, BATS, Ubuntu source-checkout, macOS smoke, and branch policy; v1.8.0 release preflight and publication passed | GA pin and release pass |
| Base Demo | First-party representative consumer | merged [#217](https://github.com/basefoundry/base-demo/pull/217) at `fb7a2b6` | CI and source-checkout workflows pin GA commit `b424376` (v2.0.0) | Local full validation and hosted validate, Ubuntu, and source-checkout checks passed | GA pin and validation pass |
| BankBuddy | Adjacent repository; no direct `base-bash-libs` reference | `e32561c` | None | Repository validation: **312 passed** | Excluded from the consumer count |
| BanyanLabs | Adjacent repository; no direct `base-bash-libs` reference | `15ef6cd` | None | Repository baseline present | Excluded from the consumer count |
| Homebrew | First-party package-manager consumer | merged [#85](https://github.com/basefoundry/homebrew-base/pull/85), bottle release `base-v1.8.0` | `base-bash-libs` v2.0.0 bundle and Base v1.8.0 archive are hash-pinned; both macOS bottles published | Both bottle builds and v2 API smoke tests passed; installed GA upgrade, formula tests, and rollback to Base 1.7.0/base-bash-libs 1.4.0 passed | GA formula, bottles, upgrade, and rollback pass |

The Base and Base Demo checkouts are controlled by the primary author. They
are valuable first-party regression signals, but they do not satisfy the
independent-consumer acceptance criterion.

## Deployment and upgrade coverage

The framework's own contract tests cover source, generated, vendored, and
standalone bundle/project-kit layouts. The RC rehearsal additionally covered
an installed Homebrew package and restoration to the prior stable package.
No independent production consumer has yet supplied a reproducible run
covering installed, vendored, and bundled deployments together.

The local vendor and reference-application rollback suites pass. The
Homebrew GA rehearsal upgraded Base 1.7.0/base-bash-libs 1.4.0 to the paired
Base 1.8.0/base-bash-libs 2.0.0 bottles, ran both formula tests, and restored
the stable pair successfully after Homebrew's normal reinstall path reported
stale Cellar links.

## Findings and limitations

- The Base and Base Demo hosted GA pin suites found no new `base-bash-libs`
  API or behavior finding.
- The v2 release archive is a deterministic bundle, not the v1 full-source
  archive. The GA Homebrew formula must therefore install the bundle layout
  and use the `base_` API in its smoke test.
- Base Demo local full validation passed with isolated Go and Gradle caches;
  the hosted Ubuntu and source-checkout jobs passed as well.
- There are no permissioned public users or case studies yet, so
  `docs/who-uses-base-bash.md` intentionally remains empty.
- The framework's community foundation (Code of Conduct, public roadmap,
  issue forms, contribution guidance, and validation template) is in place;
  a second maintainer and recurring external review are not yet established.

## Remaining #239 gates

The issue remains open for the work that requires real external participation:

1. Recruit 3–5 external design partners and validate at least three
   production applications not controlled by the primary author.
2. Capture independent installed, vendored, and bundled deployment results
   plus an immutable v2 RC-to-GA (or later v2) upgrade/rollback.
3. Link every externally reported security, compatibility, performance,
   usability, and documentation finding to a resolved issue or an explicitly
   accepted limitation.
4. Publish a permissioned case study or durable downstream compatibility
   fixture and record the outcome in the validation register.
5. Establish ongoing review and maintenance by at least one contributor beyond
   the original author.
