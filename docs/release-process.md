# base-bash-libs Release Process

This repository declares its release contract in
[`base_manifest.yaml`](../base_manifest.yaml). It is consumed by Base's guarded
release commands and is the source of truth for the version file, changelog,
GitHub Release, and Homebrew handoff.

The repository release line and its temporary publication gates are defined in
the [versioning policy](versioning-policy.md). Always enter the release workflow
through [`scripts/release`](../scripts/release); do not invoke
`basectl release` directly. The repository guard validates the candidate before
delegating safe operations to Base's generic release machinery.
The shared provider, platform, license, and release-artifact rules are
summarized in the [Base ecosystem platform, license, and release
policy](https://github.com/basefoundry/base/blob/main/docs/ecosystem-policy.md).

## Standard Sequence

1. Create or choose a release issue and set its repository Project metadata.
2. Create a release-preparation branch and dedicated worktree from
   `origin/main`.
3. Move the relevant `Unreleased` entries in `CHANGELOG.md` into a dated
   release section. Update `VERSION` and the top release row in `README.md` to
   the same version. Ordinary pull requests do not change `VERSION`.
4. Build and verify the canonical release asset set from the tagged commit:

   ```bash
   scripts/release-artifact build --version X.Y.Z --commit <full-tag-sha> \
     --output /private/tmp/base-bash-libs-X.Y.Z
   scripts/release-artifact verify /private/tmp/base-bash-libs-X.Y.Z
   ```

   After the GitHub Release exists, perform the remote completion check from a
   clean checkout as well:

   ```bash
   scripts/release-artifact verify-remote --version X.Y.Z --commit <full-tag-sha> \
     --output /private/tmp/base-bash-libs-X.Y.Z-remote
   ```

   This check reads the published release, rejects draft or mismatched tags,
   requires all four canonical assets, downloads them into private staging,
   and runs the same offline verifier against the expected commit. A missing
   or partial upload fails closed and leaves no verification directory, so a
   retry cannot accidentally consume a partial asset set.

   The output contains a deterministic archive, an SPDX 2.3 SBOM, a
   reproducibility/provenance statement, and a checksum manifest. The archive
   embeds `lib/bash/base-bash-libs.release` with the exact release version,
   tag commit, `dirty_state=clean`, and `provenance=release-artifact`; this
   metadata is generated in the artifact rather than committed with a
   self-referential commit hash. Offline verification requires exactly one
   same-version archive, SBOM, provenance statement, and checksum manifest.
   The checksum manifest must cover every mandatory asset exactly once, while
   the provenance subject, SBOM namespace/package, and embedded metadata must
   agree on the archive digest, version, and full source commit. Treat any
   missing, duplicate, traversal-bearing, or inconsistent record as a failed
   release gate; do not choose one asset from an ambiguous directory.
   Archive file and directory timestamps are normalized in UTC, path ordering
   uses the `C` locale, and archive creation supports GNU tar and bsdtar only;
   other tar implementations fail closed rather than claiming reproducibility.
   Generate the repository component row for the ecosystem BOM from the same
   immutable commit:

   ```bash
   scripts/release-bom-row --version X.Y.Z --commit <full-tag-sha> \
     --platform macos-14 --platform ubuntu-24.04 \
     --evidence run://base-bash-libs/validation \
     --output /private/tmp/base-bash-libs-X.Y.Z-row.json
   ```
5. Run the full library validation and inspect the diff:

   ```bash
   ./tests/validate.sh
   git diff --check
   ```

   The release-invariant stage derives two API references from the checked-out
   release contract. It validates the candidate tree at `HEAD` against the
   published compatibility baseline from `first-party-cutover.yaml`, including
   when `VERSION` has advanced for release preparation. Both references and
   provenance are printed in diagnostics. `BASE_BASH_LIBS_COMPATIBILITY_REF`
   remains available for explicit audited fixture overrides, but is not needed
   for the documented local or CI command.

6. Open and merge the release-preparation pull request.
7. Sync local `main`, then inspect the release from the repository root:

   ```bash
   scripts/release refs --version X.Y.Z
   scripts/release check --version X.Y.Z --manifest base_manifest.yaml \
     --bom /private/tmp/base-ecosystem-X.Y.Z.json
   scripts/release plan --version X.Y.Z --manifest base_manifest.yaml
   scripts/release notes --version X.Y.Z --manifest base_manifest.yaml
   scripts/release publish --version X.Y.Z --manifest base_manifest.yaml \
     --bom /private/tmp/base-ecosystem-X.Y.Z.json --dry-run
   ```

   The `refs` preflight is mandatory before any real publication attempt. It
   fails closed if the candidate tag exists locally or on `origin`, or if
   either side cannot be inspected.

8. Publish only after the readiness checks pass. Use `--yes` only from a
   trusted non-interactive release shell:

   ```bash
   scripts/release publish --version X.Y.Z --manifest base_manifest.yaml \
     --bom /private/tmp/base-ecosystem-X.Y.Z.json --yes
   ```

9. Verify the annotated `vX.Y.Z` tag and the GitHub Release for
   `basefoundry/base-bash-libs`.

## Homebrew Handoff

The release contract requires the tap-owned formula
`basefoundry/base/base-bash-libs` in `basefoundry/homebrew-base`.

After the GitHub Release and its verified canonical source asset exist:

1. Create a tap release branch and update `Formula/base-bash-libs.rb` to the
   uploaded canonical archive URL, version, SHA256, and version assertions in
   the formula test. Do not use GitHub's automatic `archive/refs/tags/...` URL
   for v2. Read back the exact release asset and checksum before opening the
   tap pull request.
2. Validate the formula from the tap checkout:

   ```bash
   brew install --build-from-source Formula/base-bash-libs.rb
   brew test basefoundry/base/base-bash-libs
   brew audit --new --formula Formula/base-bash-libs.rb
   ```

3. Publish any tap bottle artifacts required by the tap policy, then open and
   merge the tap pull request.
4. Smoke-test a consumer install and verify that `BASE_BASH_LIBS_VERSION` and
   the `base-bash` launcher report the new version.

## Base Handoff

Base pins this repository by full commit SHA in its GitHub Actions workflows.
After the release, update the Base pin to the release commit, run Base's
source-checkout and integration tests, and record the dependency update in the
Base changelog when it is user-visible or release-relevant.

## Finish

Record the library release URL, asset checksums and provenance, Homebrew tap
pull request, and Base dependency pull request on the release issue. Remove the
release worktree and merged branches when safe. Do not publish a release while
the worktree is dirty, the version metadata disagrees, the changelog section is
missing, the repository release guard blocks the candidate, or a declared
downstream handoff has not been completed or explicitly deferred.
