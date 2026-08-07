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

1. Create or choose a GitHub issue before starting implementation work.
   Contributions from a public fork are welcome, but the issue and
   pull-request contract still applies.
2. Give the issue exactly one primary category label:
   - `bug` for defects or regressions.
   - `enhancement` for new capabilities, refactors, and maintenance.
   - `documentation` for documentation-only work.
   - `ci` for workflows, tests, release automation, or CI reliability.
   - `security` for security hardening, dependency pinning, or vulnerabilities.
3. If the issue is tracked in the repository Project, move it to `In Progress`
   before branch or worktree work begins. Move it to `In Review` when the pull
   request opens, and verify it is `Done` after merge or closure.
4. Create an issue-backed branch:

   ```text
   <category>/<issue>-<YYYYMMDD>-<slug>
   ```

   The category must match the issue's one primary category label, and the date
   must be a real calendar date. The branch-name ruleset and the trusted
   `base/issue-branch-policy` workflow enforce this for every contribution.
5. Use a dedicated Git worktree for each pull request so the main checkout can
   stay on the default branch:

   ```bash
   git fetch origin
   git worktree add -b <branch> ../base-bash-libs-worktrees/<slug> origin/<default-branch>
   ```

6. Keep the pull request scoped to one issue and link it with `Fixes #<issue>`
   or `Closes #<issue>` when merge should close the issue. Fill in the standard
   `Summary`, `Issue`, and `Validation` sections plus any applicable impact
   sections required by `base_manifest.yaml`.
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
to write to the organization Project. If issues are missing from the Project,
check GraphQL quota before starting a backfill:

```bash
gh api graphql -f query='query { rateLimit { remaining resetAt } }'
```

Dispatch missed issues slowly so Project field mutations do not exhaust the
GraphQL quota:

```bash
for issue in <issue-numbers>; do
  gh workflow run project-intake.yml --repo basefoundry/base-bash-libs -f issue_number="$issue"
  sleep 12
done
```
