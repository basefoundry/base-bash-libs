# base-bash-libs Release Process

This repository declares its release contract in
[`base_manifest.yaml`](../base_manifest.yaml). It is consumed by Base's guarded
release commands and is the source of truth for the version file, changelog,
GitHub Release, and Homebrew handoff.

## Standard Sequence

1. Create or choose a release issue and set its repository Project metadata.
2. Create a release-preparation branch and dedicated worktree from
   `origin/main`.
3. Move the relevant `Unreleased` entries in `CHANGELOG.md` into a dated
   release section. Update `VERSION` and the top release row in `README.md` to
   the same version. Ordinary pull requests do not change `VERSION`.
4. Run the full library validation and inspect the diff:

   ```bash
   ./tests/validate.sh
   git diff --check
   ```

5. Open and merge the release-preparation pull request.
6. Sync local `main`, then inspect the release from the repository root:

   ```bash
   basectl release check --version X.Y.Z --manifest base_manifest.yaml
   basectl release plan --version X.Y.Z --manifest base_manifest.yaml
   basectl release notes --version X.Y.Z --manifest base_manifest.yaml
   basectl release publish --version X.Y.Z --manifest base_manifest.yaml --dry-run
   ```

7. Publish only after the readiness checks pass. Use `--yes` only from a
   trusted non-interactive release shell:

   ```bash
   basectl release publish --version X.Y.Z --manifest base_manifest.yaml --yes
   ```

8. Verify the annotated `vX.Y.Z` tag and the GitHub Release for
   `basefoundry/base-bash-libs`.

## Homebrew Handoff

The release contract requires the tap-owned formula
`basefoundry/base/base-bash-libs` in `basefoundry/homebrew-base`.

After the GitHub Release exists:

1. Create a tap release branch and update `Formula/base-bash-libs.rb` to the
   new archive URL, version, SHA256, and version assertions in the formula test.
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

Record the library release URL, Homebrew tap pull request, and Base dependency
pull request on the release issue. Remove the release worktree and merged
branches when safe. Do not publish a release while the worktree is dirty, the
version metadata disagrees, the changelog section is missing, or a declared
downstream handoff has not been completed or explicitly deferred.
