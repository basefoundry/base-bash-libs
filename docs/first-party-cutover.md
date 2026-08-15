# First-party v2 cutover

Issue #240 records the first-party promotion handoff. The exact v2 GA asset,
checksum, and provenance exist, and Base, Base Demo, and Homebrew now point at
the immutable release or its verified bottle release.

## Inventory and order

[`first-party-cutover.yaml`](../first-party-cutover.yaml) is the machine-readable
inventory. The release order is:

1. publish `base-bash-libs` v2.0.0 with immutable tag, source/bundle checksum,
   SBOM, and provenance;
2. update Base to the `base_` API and raise its minimum to `2.0.0` (the
   issue-backed migration landed in [Base #1936](https://github.com/basefoundry/base/pull/1936));
3. update Base Demo's vendored/install pin and source-checkout CI to the exact
   tag plus full commit;
4. update the Homebrew formula URL, version, checksum, bottle release, and
   namespaced test expectations; and
5. verify installed, vendored, bundled, and rollback paths in every consumer.

The release asset gate is satisfied when `release_status` is `published`, the
archive SHA256 matches the uploaded canonical bundle, and the provenance asset
names the exact merge commit. Consumer promotion is complete only after each
pin and formula points at that same immutable asset and passes its hosted
checks. That condition is now satisfied for the first-party consumers.

## Verification and rollback

Run `scripts/first-party-cutover check` to validate the manifest and the
completed consumer states. It requires `release_status: published`, a full
SHA-256, the exact tag on the remote, and no pending consumer promotion.
Verify each consumer's smoke tests before treating the cutover as complete.

If a consumer fails, stop the order, restore its prior immutable pin, and keep
the v2 asset/tag unchanged. Never retag a different commit or silently fall
back to a moving branch. Record the failure and corrected checksums in the
release notes, then resume from the failed consumer after a reviewed fix.

## Current state

Base's `basectl help` integration defect is fixed in the merged issue-backed PR
above and validated locally against the v2 API. Base v1.8.0, Base Demo, and the
Homebrew `base-v1.8.0` bottle release consume the verified v2.0.0 GA asset.
