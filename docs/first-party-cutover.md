# First-party v2 cutover

Issue #240 is the release handoff, not permission to publish an unverified
dependency. The exact v2 GA asset, checksum, and provenance must exist before
any downstream pin changes.

## Inventory and order

[`first-party-cutover.yaml`](../first-party-cutover.yaml) is the machine-readable
inventory. The release order is:

1. publish `base-bash-libs` v2.0.0 with immutable tag, source/bundle checksum,
   SBOM, and provenance;
2. update Base to the `base_` API and raise its minimum to `2.0.0` (the current
   issue-backed migration is [Base #1881](https://github.com/basefoundry/base/pull/1881));
3. update Base Demo's vendored/install pin and source-checkout CI to the exact
   tag plus full commit;
4. update the Homebrew formula URL, version, checksum, bottle release, and
   namespaced test expectations; and
5. verify installed, vendored, bundled, and rollback paths in every consumer.

The cutover is blocked while `release_status` is `pending-ga-asset`. This is a
deliberate fail-closed state; changing a version string before the asset exists
would make a reproducible install impossible.

## Verification and rollback

Run `scripts/first-party-cutover check --allow-pending` during the train to
validate the manifest and inspect staged consumer trees. The final check omits
`--allow-pending` and requires `release_status: published`, a full SHA-256, and
the exact tag on the remote. Verify each consumer's smoke tests before the next
publish step.

If a consumer fails, stop the order, restore its prior immutable pin, and keep
the v2 asset/tag unchanged. Never retag a different commit or silently fall
back to a moving branch. Record the failure and corrected checksums in the
release notes, then resume from the failed consumer after a reviewed fix.

## Current state

Base's `basectl help` integration defect is fixed in the merged issue-backed PR
above and validated locally against the v2 API. Base Demo and Homebrew remain
intentionally unchanged until the v2 GA artifact is published; their current
v1.4 pins are historical inputs to the final cutover checklist.
