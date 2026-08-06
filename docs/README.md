# Base Bash documentation

The current documentation version is **v2**. It describes the clean-break
`base_` API and the professional application contract. Pre-v2 material is
historical and unsupported; use the [v1.4.0 → v2 migration guide](v2/migration-v1.4-to-v2.md)
when updating an existing script.

## Start here

- [Five-minute quickstart](v2/quickstart.md)
- [Architecture and execution model](v2/architecture.md)
- [API reference](api-reference.md) and [v2 API contract](v2-api-contract.md)
- [Configuration, lifecycle, and status contracts](v2/architecture.md#application-contract)
- [Testing, vendoring, bundling, and release](v2/architecture.md#delivery)
- [CI and default-branch policy](ci-policy.md)
- [Support and threat model](support-policy.md) · [security reporting](../SECURITY.md)

The quickstart is deliberately pinned to an immutable release ref. It never
uses the moving default branch or an unreleased `main` checkout.
