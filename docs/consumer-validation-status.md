# Consumer validation status

Last validated: 2026-08-07

This is an internal readiness ledger for the #239 adoption work. It records
what can be reproduced from the current local checkouts; it is not a public
adoption claim. Independent users belong in the permissioned
[validation register](who-uses-base-bash.md) only after a downstream owner
has approved publication.

## Framework reference

The validation below used the `base-bash-libs` source checkout at
`240494088bf362d3055765818e22b152425b15af` (the `main` tip before this
ledger was added). The checkout reports version `2.0.0`, but there is not yet
a published v2 RC, GA tag, or release asset. Results therefore describe
pre-release source validation, not support for an immutable v2 release.

## Consumer matrix

| Checkout | Relationship | Reference | Deployment exercised | Result | Classification |
| --- | --- | --- | --- | --- | --- |
| Base | First-party direct consumer | `3aa5934` | Sibling source checkout | Full `base-test`: **944 passed, 1 skipped** | Pass; useful readiness evidence, not independent adoption evidence |
| Base Demo | First-party representative consumer | `f48bee9` | Source checkout | Targeted BATS suite: **46 passed**. Full validation is blocked by Gradle's missing macOS arm64 `libnative-platform.dylib`. | Partial; environment limitation, not attributed to `base-bash-libs` |
| BankBuddy | Adjacent repository; no direct `base-bash-libs` reference | `e32561c` | None | Repository validation: **312 passed** | Excluded from the consumer count |
| BanyanLabs | Adjacent repository; no direct `base-bash-libs` reference | `15ef6cd` | None | Repository baseline present | Excluded from the consumer count |

The Base and Base Demo checkouts are controlled by the primary author. They
are valuable first-party regression signals, but they do not satisfy the
independent-consumer acceptance criterion.

## Deployment and upgrade coverage

The framework's own contract tests cover source, generated, vendored, and
standalone bundle/project-kit layouts. No independent production consumer has
yet supplied a reproducible run covering installed, vendored, and bundled
deployments together.

An RC-to-GA (or later v2) upgrade and rollback cannot be validated until an
immutable v2 RC and GA/replacement asset exist. That release prerequisite is
tracked by [#240](https://github.com/basefoundry/base-bash-libs/issues/240)
and [#215](https://github.com/basefoundry/base-bash-libs/issues/215).

## Findings and limitations

- The current Base full suite found no new `base-bash-libs` API or behavior
  finding.
- The Base Demo Gradle failure is recorded as an environment limitation for
  this run. It should not be presented as a framework defect without a
  compatible Gradle/native-platform reproduction.
- There are no permissioned public users or case studies yet, so
  `docs/who-uses-base-bash.md` intentionally remains empty.
- The framework's community foundation (Code of Conduct, public roadmap,
  issue forms, contribution guidance, and validation template) is in place;
  a second maintainer and recurring external review are not yet established.

## Remaining #239 gates

The issue remains open for the work that requires real external participation:

1. Recruit 3–5 external design partners and validate at least three
   production applications not controlled by the primary author.
2. Capture installed, vendored, and bundled deployment results plus an
   immutable v2 RC-to-GA (or later v2) upgrade/rollback.
3. Link every externally reported security, compatibility, performance,
   usability, and documentation finding to a resolved issue or an explicitly
   accepted limitation.
4. Publish a permissioned case study or durable downstream compatibility
   fixture and record the outcome in the validation register.
5. Establish ongoing review and maintenance by at least one contributor beyond
   the original author.

