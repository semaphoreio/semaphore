# Repository Guidelines

## Project Structure & Module Organization
Core modules live under `lib/secrethub/**` with the OTP entry point in `lib/secrethub.ex`. Generated gRPC stubs populate `lib/internal_api` and `lib/public_api`; refresh them via the proto Make targets. Configuration sits in `config/*.exs`, assets and keys in `priv/`, and ExUnit tests mirror the tree in `test/**` with helpers in `test/support/`. Versioned `.proto` sources live in `proto/`, with helper scripts under `scripts/`.

## Build, Test, and Development Commands
- `mix deps.get` installs Elixir dependencies for the current `MIX_ENV`.
- `mix compile` builds the app locally; run before committing generated code.
- `mix test` runs ExUnit; narrow scope with `mix test path/to/file_test.exs`.
- `mix credo --strict` applies the lint rules enforced in `.credo.exs`.
- `make test.ex.setup` boots Docker services, runs migrations, and seeds the test DB.
- `make pb.gen.internal` / `make pb.gen.public` regenerate gRPC stubs via the scripts in `scripts/`.

## Coding Style & Naming Conventions
Run `mix format` before every commit; it enforces `.formatter.exs` and two-space indentation. Keep modules under the `Secrethub.*` namespace, align pipelines, and name files with `snake_case.ex` and tests with `*_test.exs`. Address Credo findings locally so CI stays clean.

## Testing Guidelines
Tests use ExUnit with shared helpers in `test/support`. Prefer descriptive names (`test "revokes token"`). Use the provided data-case helpers for database scenarios and add gRPC fixtures under `test/support` when mocking upstream calls. Ensure suites pass with `mix test`; CI toggles the bundled `JUnitFormatter` when needed.

## Commit & Pull Request Guidelines
History follows conventional commits such as `feat(guard): add posthog integration` or `fix: lock go tool versions`. Start with an imperative summary, include the relevant scope, and reference issues in parentheses (e.g. `(#598)`). Pull requests should explain intent, list validation steps (`mix test`, `mix credo`), and attach screenshots or payload samples for behavioral changes.

## Security & Configuration Tips
Environment variables defined in the `Makefile` inject credentials for Postgres, RabbitMQ, and external services; never commit real secrets, just use the provided placeholders. Keep generated protobuf code aligned with upstream schemas and audit new dependencies with `mix deps.unlock --check-unused`.
