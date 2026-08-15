# Consumer validation status

Last validated: 2026-08-15

This is an internal readiness ledger for the #239 adoption work. It records
what can be reproduced from the current local checkouts; it is not a public
adoption claim. Independent users belong in the permissioned
[validation register](who-uses-base-bash.md) only after a downstream owner
has approved publication.

## Framework reference

The validation below used the immutable `base-bash-libs` v2.0.0-rc.1
candidate at commit
`c134fb8a3397e2cfee1d90845cec44f56dacae7b`. The annotated tag
[v2.0.0-rc.1](https://github.com/basefoundry/base-bash-libs/releases/tag/v2.0.0-rc.1)
and its canonical archive, SHA256SUMS, SPDX SBOM, and provenance assets were
downloaded and verified. This is RC evidence, not a GA support claim.

## Consumer matrix

| Checkout | Relationship | Reference | Deployment exercised | Result | Classification |
| --- | --- | --- | --- | --- | --- |
| Base | First-party direct consumer | merged [6038cba](https://github.com/basefoundry/base/commit/6038cbaf93eb21ccb26c17a612aded85deedb04b) | CI pinned to `c134fb8` (v2.0.0-rc.1) | PR [#1934](https://github.com/basefoundry/base/pull/1934): Python/pylint, integration, security, BATS, Ubuntu source-checkout, macOS smoke, and branch policy all passed | Pass; useful readiness evidence, not independent adoption evidence |
| Base Demo | First-party representative consumer | merged [b54bf00](https://github.com/basefoundry/base-demo/commit/b54bf008a9dfb542c5c51dc919c3e10698a2f5eb) | CI pinned to `c134fb8` (v2.0.0-rc.1) | PR [#214](https://github.com/basefoundry/base-demo/pull/214): validation, Ubuntu, source-checkout, and branch policy all passed; local full validation passed with isolated caches | Pass; useful readiness evidence, not independent adoption evidence |
| BankBuddy | Adjacent repository; no direct `base-bash-libs` reference | `e32561c` | None | Repository validation: **312 passed** | Excluded from the consumer count |
| BanyanLabs | Adjacent repository; no direct `base-bash-libs` reference | `15ef6cd` | None | Repository baseline present | Excluded from the consumer count |
| Homebrew | First-party package-manager consumer | stable tap remains `v1.4.0` | Disposable RC tap using canonical `v2.0.0-rc.1` archive | `brew audit --new`, source build, formula smoke test, and stable restore all passed; stable tap was not changed | Pass for RC rehearsal; GA formula PR remains pending |

The Base and Base Demo checkouts are controlled by the primary author. They
are valuable first-party regression signals, but they do not satisfy the
independent-consumer acceptance criterion.

## Deployment and upgrade coverage

The framework's own contract tests cover source, generated, vendored, and
standalone bundle/project-kit layouts. The RC rehearsal additionally covered
an installed Homebrew package and restoration to the prior stable package.
No independent production consumer has yet supplied a reproducible run
covering installed, vendored, and bundled deployments together.

The local vendor and reference-application rollback suites pass, and the
Homebrew RC-to-v1.4 restore was rehearsed. A true RC-to-GA upgrade still
cannot be validated until the immutable `v2.0.0` GA asset exists. That
remaining release prerequisite is tracked by
[#240](https://github.com/basefoundry/base-bash-libs/issues/240) and
[#215](https://github.com/basefoundry/base-bash-libs/issues/215).

## Findings and limitations

- The Base and Base Demo hosted RC pin suites found no new `base-bash-libs`
  API or behavior finding.
- The v2 release archive is a deterministic bundle, not the v1 full-source
  archive. The GA Homebrew formula must therefore install the bundle layout
  and use the `base_` API in its smoke test; the v1.4 formula remains
  intentionally unchanged until that GA handoff.
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
