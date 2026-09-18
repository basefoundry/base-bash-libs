# Contributing to base-bash-libs

Thank you for improving this project.

For coding and documentation standards, see [STANDARDS.md](STANDARDS.md). This
repository inherits Base's shell-library standards, including the convention
that each sourceable shell library remains a single file at its library
boundary.

For release work, read [docs/release-process.md](docs/release-process.md). The
repository release contract is declared in `base_manifest.yaml`; ordinary pull
requests leave `VERSION` unchanged. The active release line is documented in
[docs/versioning-policy.md](docs/versioning-policy.md), and every release
operation must enter through the repository-owned `scripts/release` guard.

## Workflow

1. For tracked work, create or choose a GitHub issue before starting
   implementation work. Contributions from a public fork are welcome. A
   genuinely small, self-contained fix may use the documented small-fix
   exception without a pre-existing issue; the maintainer applies its primary
   category label after reviewing the scope.
   Issues labeled `good first issue` are intentionally offered to community
   contributors. Maintainer issue sweeps and implementation trains must
   exclude them by default, even when their Project status is `Ready`; report
   them separately as contributor-reserved work. Only take one into maintainer
   work when it is specifically selected. Before starting that work, remove
   the `good first issue` label so contributors are not invited to duplicate
   it, then follow the normal Project and issue/PR workflow below.
2. Give each tracked issue exactly one primary category label. For a small-fix
   pull request, the maintainer applies exactly one primary category label:
   - `bug` for defects or regressions.
   - `enhancement` for new capabilities, refactors, and maintenance.
   - `documentation` for documentation-only work.
   - `ci` for workflows, tests, release automation, or CI reliability.
   - `security` for security hardening, dependency pinning, or vulnerabilities.
3. If tracked work is in the repository Project, move its issue to `In Progress`
   before branch or worktree work begins. Move it to `In Review` when the pull
   request opens, and verify it is `Done` after merge or closure. Small-fix
   contributions have no issue card to move.
4. Create a branch using one of these forms:

   ```text
   <category>/<issue>-<YYYYMMDD>-<slug>  # tracked work
   small-fix/<YYYYMMDD>-<slug>            # narrow fix without an issue
   ```

   For tracked work, the category must match the issue's one primary category
   label. For a small fix, the maintainer must apply exactly one primary
   category label to the pull request. In both forms, the date must be a real
   calendar date. The branch-name ruleset and trusted
   `base/issue-branch-policy` workflow enforce these rules.
5. Use a dedicated Git worktree for tracked pull requests so the main checkout
   can stay on the default branch. A small-fix contributor may work from a
   normal clone using standard Git:

   ```bash
   git fetch origin
   git worktree add -b <branch> ../base-bash-libs-worktrees/<slug> origin/<default-branch>
   ```

6. Keep tracked pull requests scoped to one issue and link them with `Fixes
   #<issue>` or `Closes #<issue>` when merge should close the issue. A small-fix
   pull request may use `Related to #<issue>` when an issue exists, but no issue
   is required. Fill in the standard `Summary`, `Issue`, and `Validation`
   sections plus any applicable impact sections required by `base_manifest.yaml`.
7. Run the project checks before opening or updating a pull request. The full
   hosted tests and quality workflows remain release gates even though the
   default branch baseline does not require every job as a merge check.
8. Update `CHANGELOG.md` only for notable user-visible or release-worthy
   changes.
9. After merge, sync the default branch, remove the worktree, and delete merged
   local and remote branches when safe:

   ```bash
   git pull --ff-only origin <default-branch>
   git worktree remove ../base-bash-libs-worktrees/<slug>
   git branch -d <branch>
   git push origin --delete <branch>
   ```

Useful commands:

```bash
./tests/validate.sh
tests/lint-warnings.sh
basectl check base-bash-libs
basectl doctor base-bash-libs
basectl test base-bash-libs
```

## Project intake backfill

The `Project Intake` workflow uses the `BASE_PROJECT_TOKEN` repository secret
to write to organization Project #8 through the REST Projects API. The token
must have access to the repository and write access to the Project. Intake
does not depend on GraphQL quota. It initializes missing fields, preserves
existing metadata and active open-issue status (including status changes made
by linked-PR automation during intake), moves closed issues to `Done`,
and resets `Done` to `Backlog` for reopened issues. Every run reads back all
five managed fields before reporting success.

If issues are missing from the Project, pace manual backfills to avoid REST
secondary limits:

```bash
for issue in <issue-numbers>; do
  gh workflow run project-intake.yml --repo basefoundry/base-bash-libs -f issue_number="$issue"
  sleep 12
done
```

The workflow retries transient REST failures up to three attempts and bounds
post-add visibility and field-readback retries. Authentication, permission,
configuration, persistent API failures, and readback mismatches still fail
the run. For a rate-limit failure, respect GitHub's reset time or `Retry-After`
before dispatching again; rotating a valid token is unnecessary. See the
[REST Projects API documentation](https://docs.github.com/en/rest/projects/items).

Run the offline workflow regression tests with
`python3 tests/project-intake-test.py`; they also run in `./tests/validate.sh`.
