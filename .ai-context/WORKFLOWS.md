# Workflows

Start with the [v2 quickstart](../docs/v2/quickstart.md) and a verified immutable
release when building a consumer. `base-bash check --project .` inspects a
consumer without changing it. Library development uses the repository checks:

```bash
./tests/validate.sh
./tests/lint-warnings.sh
git diff --check
```

Focused BATS tests accompany behavior changes. The complete validator also
covers API/namespace contracts, release artifacts, consumer examples, and
compatibility. Use supported Bash and the documented development dependencies;
run timeout/process tests with non-terminal stdin.

Tracked work starts from an issue and a dedicated canonical worktree. Move its
Project item to In Progress before implementation and In Review when the PR opens.
Leave contributor-reserved good-first-issue work to its intended audience unless
explicitly selected. Ordinary PRs do not change VERSION. Releases must enter
through `scripts/release` and follow the repository's release process, including
artifact and downstream evidence.

Sources: [contribution guide](../CONTRIBUTING.md), [agent guidance](../AGENTS.md),
[release process](../docs/release-process.md), and
[versioning policy](../docs/versioning-policy.md).
