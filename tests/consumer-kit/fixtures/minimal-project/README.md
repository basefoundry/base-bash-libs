# Minimal consumer fixture

This fixture is intentionally small and offline. It exercises the same
`bin/app`, `lib/app.sh`, configuration pin, and BATS entrypoints emitted by
`base-bash init --profile minimal`.

The application reports the project `VERSION`; `BASE_BASH_LIBS_PIN` identifies
the separate framework dependency.
