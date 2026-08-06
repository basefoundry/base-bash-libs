# Integration map

base-bash-libs supplies runtime libraries and a project kit; it is not a CLI
parser generator, linter, shell replacement, or package manager. Pair it with
the tools below according to the project's needs.

| Tool/project | Role | Integration guidance |
| --- | --- | --- |
| Bashly | declarative CLI generator | let generated dispatch call `base_cli_run`; keep the generated app module single-file |
| Argc / Argbash | argument/CLI generation | translate generated values into the v2 command schema; do not source generated text as config |
| Bats | behavior tests | use `tests/consumer-kit/test_helper.bash` and run the generated suite in CI |
| ShellCheck / shfmt | static analysis/formatting | run with Bash dialect and repository severity policy; warnings remain review input |
| Modernish | portability probes | useful for targeted portability checks, but the supported contract is the v2 matrix |
| boilerplates | project starting points | compare maintenance, strict-mode, and dependency assumptions before adopting |
| bpkg / Basher / Basalt | package distribution | consume only immutable verified metadata; see `docs/pinned-consumption.md` |

These are factual integration boundaries, not a claim that one project is
universally better. The release workflow and support policy remain authoritative
when a third-party tool has a broader or different runtime promise.
