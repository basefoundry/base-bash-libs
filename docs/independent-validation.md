# Independent consumer validation template

This template is for a consumer not controlled by the primary base-bash-libs
author. Do not include credentials or private source. A maintainer and the
consumer owner must approve any public case study.

```text
Consumer/project:
Maintainer contact and publication permission:
Application purpose and approximate deployment:
Framework reference (tag + full commit or verified asset checksum):
Deployment modes exercised: installed / vendored / bundled
Bash and OS/libc matrix:
Installation and first-run result:
Normal operation and output/status result:
Failure, interruption, and cleanup result:
v2 RC-to-GA or later v2 upgrade and rollback result:
Issues found and links to fixes or accepted limitations:
Follow-up owner and date:
```

The minimum evidence is a reproducible command/test log and the exact
immutable reference. A claim of production use is not accepted from a local
demo or an internal reference application alone.

The current first-party readiness results are recorded separately in the
[consumer validation status ledger](consumer-validation-status.md). That
ledger is intentionally not an independent-consumer claim.
