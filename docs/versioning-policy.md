# Versioning and Release-Line Policy

## Current Release Line

`v1.4.0` remains the last stable Base Bash release until the verified
`v2.0.0` GA asset is published. The release-preparation candidate is now
`v2.0.0`; the 5/5 initiative has one stable target and will not create a
stable `v1.5.0` or reset the version to 0.x.

Those choices would either hide breaking changes inside the current 1.x
compatibility range or move version precedence backward.

The only planned v2 identifiers before GA are:

```text
2.0.0-alpha.N
2.0.0-beta.N
2.0.0-rc.N
2.0.0
```

`N` starts at 1, increases within a phase, and has no leading zeroes. These
identifiers use SemVer syntax, but prereleases may contain breaking changes and
do not receive compatibility shims. The stable SemVer compatibility contract
begins at `v2.0.0` GA.

After GA, v2 is the only supported release line. Versions through `v1.4.0`
remain available as historical releases but no longer receive fixes or support.
Additive features and fixes remain within 2.x; a breaking stable API change
requires v3 or later.

## Release Gates

The repository-owned [`scripts/release`](../scripts/release) command is the
mandatory entry point for every release inspection and publication attempt. It
enforces the permitted v2 identifiers before delegating read-only operations
and dry runs to Base's guarded release command.

Real prerelease publication remains locked until #233 provides deterministic,
verified release assets and provenance. Real `v2.0.0` publication remains
locked until the engineering, policy, documentation, integration, and reference
application gates in #214 are complete and the pre-GA work in #240 has validated
and rehearsed the exact release candidate across Base, Base Demo, Homebrew,
vendored, and bundled paths. The remaining #240 steps then publish compatible
Base and Homebrew updates after the Base Bash GA asset exists.

The lock is code-reviewed policy, not an environment-variable or sentinel-file
override. The PR that satisfies each gate must update the guard and its tests.
Until then, maintainers can inspect a candidate without changing GitHub state:

```bash
scripts/release check --version 2.0.0-rc.1 --manifest base_manifest.yaml
scripts/release plan --version 2.0.0-rc.1 --manifest base_manifest.yaml
scripts/release publish --version 2.0.0-rc.1 --manifest base_manifest.yaml --dry-run
```

The generic `basectl release` command is not a substitute for this guard. Its
current manifest contract does not encode this repository's release line,
artifact, provenance, or GA gates.

Before any real publication attempt, run the repository-owned tag preflight:

```bash
scripts/release refs --version 2.0.0-rc.1
```

The preflight checks both `refs/tags/v2.0.0-rc.1` in the local checkout and the
same tag on `origin`. It fails closed when Git cannot inspect either side or
when the tag is already present. Published tags are immutable; a stale local
tag may be removed only after confirming that the remote ref is absent and that
the local object is the withdrawn July 2026 commit documented below.

## Withdrawn July 2026 Event

On July 2, 2026, [PR #100](https://github.com/basefoundry/base-bash-libs/pull/100)
created commit
[`2d90249`](https://github.com/basefoundry/base-bash-libs/commit/2d90249eec35aa00d04513294ce0fb09042c3f3f)
with `v2.0.0` metadata. A corresponding
[Homebrew PR #66](https://github.com/basefoundry/homebrew-base/pull/66) used
GitHub's automatic tag-archive URL.

The next day, [PR #103](https://github.com/basefoundry/base-bash-libs/pull/103)
and commit
[`6ce8af0`](https://github.com/basefoundry/base-bash-libs/commit/6ce8af02031fad2c0071880b00eb6f526ae2d779)
corrected the release line to `v1.1.0`.
[Homebrew PR #68](https://github.com/basefoundry/homebrew-base/pull/68)
corrected the formula and added `version_scheme 1` so Homebrew would accept the
version-order correction.

The attempted `v2.0.0` remote tag and GitHub Release are no longer present.
The commits and pull requests remain part of the public history, and caches of
the old automatic archive may still exist. The final v2 release therefore uses
a newly verified canonical release asset rather than that automatic archive.
The project will never silently retag or represent the withdrawn artifact as
the final release.

Older local clones can retain the deleted lightweight tag. Inspect both sides
before removing a stale local ref:

```bash
git ls-remote --tags origin refs/tags/v2.0.0
git show-ref --verify refs/tags/v2.0.0
```

If the remote command has no output and the local command finds the withdrawn
ref at `2d90249eec35aa00d04513294ce0fb09042c3f3f`, remove only that local tag:

```bash
git tag -d v2.0.0
```

## Immutable Consumption

The complete checkout, archive, Homebrew, vendored, and standalone verification
procedure is maintained in [`pinned-consumption.md`](pinned-consumption.md).

Do not install from an unpinned default-branch checkout. Until a verified v2
asset exists, pin the current stable source to the full `v1.4.0` release commit:

```bash
git clone https://github.com/basefoundry/base-bash-libs.git vendor/base-bash-libs
git -C vendor/base-bash-libs checkout --detach \
  2c5ef2c3a9edfbe2cf68d0645be65b920255abff
test "$(git -C vendor/base-bash-libs rev-parse HEAD)" = \
  2c5ef2c3a9edfbe2cf68d0645be65b920255abff
```

Prerelease validation must likewise use an immutable prerelease tag resolved to
its expected commit, a verified release asset, or a full commit. Release notes,
bug reports, and CI fixtures should record the resolved commit in addition to
the human-readable version.
