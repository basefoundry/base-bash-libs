# Reference benchmark methodology

Run `benchmarks/reference-apps.sh` from a checkout pinned to the exact release
commit. It emits tab-separated raw records with the Bash version, OS, iteration
count, framework commit, total startup time, and average startup time. Redirect
the output to an artifact so the environment and raw data travel together:

```bash
BASE_REFERENCE_BENCHMARK_ITERATIONS=30 \
  benchmarks/reference-apps.sh | tee benchmark-$(date +%Y%m%d)-$(uname -s).tsv
```

The measured operation is a cold process launch through `bin/base-bash` plus
`--help` for each reference application. It excludes network, filesystem
mutation, warm-process throughput, and application-specific work. Compare only
records with the same Bash build, OS/libc, CPU/load conditions, framework
commit, and iteration count. These are engineering measurements, not a
universal performance claim.

`tests/benchmark-contract.sh` is the networkless CI contract for this output.
It runs two iterations for each reference application and checks the schema,
provenance, timing fields, application coverage, and methodology marker. It
does not treat a single host's timing as a cross-platform performance claim.
