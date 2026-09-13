# Reference benchmark methodology

Run `benchmarks/reference-apps.sh` from a checkout pinned to the exact release
commit. It emits raw records with the Bash version, OS/CPU, iteration count,
exact framework commit and dirty state, timer source/precision, stage totals,
and average startup time. Redirect
the output to an artifact so the environment and raw data travel together:

```bash
BASE_REFERENCE_BENCHMARK_ITERATIONS=30 \
  benchmarks/reference-apps.sh | tee benchmark-$(date +%Y%m%d)-$(uname -s).tsv
```

The measured operations include a plain-Bash process, stdlib source, CLI
import, and a cold process launch through `bin/base-bash` plus `--help` for
each reference application. The default engineering budget is one second per
application help launch and is reported without turning noisy host timing into
a brittle CI threshold. Low-resolution clocks are explicitly marked
`insufficient-precision` and do not receive a budget result. Compare only
records with the same Bash build, OS/libc, CPU/load conditions, framework
commit/dirty state, timer precision, and iteration count. These are engineering
measurements, not a universal performance claim.

`tests/benchmark-contract.sh` is the networkless CI contract for this output.
It runs two iterations for each reference application and checks the schema,
provenance, timing fields, application coverage, and methodology marker. It
does not treat a single host's timing as a cross-platform performance claim.
