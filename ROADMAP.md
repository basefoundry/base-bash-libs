# Public roadmap

The #214 5/5 initiative is the public roadmap. The ordered issue train,
milestone, dependencies, acceptance criteria, and pull requests are the source
of truth; this page is a short orientation for new contributors.

## Current sequence

1. v2 API and runtime contract: namespace, initialization, lifecycle, config,
   scaffold, conformance, single-file distribution, vendor verification.
2. Release trust: compatibility gates, support/security policy, versioned
   adoption docs, integrations, reference applications.
3. First-party cutover and independent validation: Base, Base Demo, Homebrew,
   external consumers, case studies, and maintainer succession.

Work is not considered complete because a document exists: each issue links
automated evidence, an immutable artifact, or an explicitly accepted limitation.
Small fixes may be submitted without first opening an issue by using the
documented `small-fix/<YYYYMMDD>-<slug>` branch form. Keep the change narrow;
the maintainer must apply exactly one primary category label before the branch
policy check can pass. Use the issue templates when a decision, vulnerability,
or multi-step change needs tracking.
