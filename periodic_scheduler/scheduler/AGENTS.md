# Repository Guidelines

## Project Structure & Module Organization
Runtime code lives under `lib/`, split by domain boundaries (`scheduler/`, `actions/`, `workers/`). Persistence details sit in `lib/scheduler/periodics` and `lib/scheduler/front_db` with schemas mirroring tables. Configuration defaults are in `config/config.exs`, with environment overrides in `config/{dev,test,prod}.exs`. Database migrations and seeds are under `priv/{periodics_repo,front_repo}/`, while `test/` mirrors `lib/` one-to-one for ExUnit coverage. Docker, release, and deployment assets reside in `docker-compose.yml`, `rel/`, and `helm/`. Shared automation scripts sit inside `scripts/`. For a deeper walkthrough, treat `DOCUMENTATION.md` as the go-to triage guide before diving into tasks.

## Build, Test, and Development Commands
- `mix deps.get && mix compile` installs dependencies and compiles the application locally.
- `MIX_ENV=test make test.ex.setup` prepares the Postgres schema inside Docker for integration tests.
- `mix test` or `mix test --cover` runs the ExUnit suite (JUnit formatter available via `MIX_ENV=test mix test --formatter JUnitFormatter` for CI).
- `mix credo --strict` runs linting, and `mix format` enforces the formatter prior to commits.
- `docker compose up app` boots the scheduler in a container with RabbitMQ/Postgres defaults from the `.env` files.

## Coding Style & Naming Conventions
Follow the default Elixir formatter (2-space indentation, pipe-first style). Modules use `Scheduler.*` namespaces that map to folders (e.g., `Scheduler.Periodic.Job` ⇔ `lib/scheduler/periodic/job.ex`). Functions are snake_case verbs, macros are camel-case nouns, and tests end in `_test.exs`. Keep public modules documented with `@moduledoc` and prefer pattern matching + guard clauses over nested conditionals. Run `mix format && mix credo` before every push.

## Testing Guidelines
Author unit tests alongside code in `test/<mirror_path>_test.exs`. Use ExUnit’s `describe` blocks per function and tag integration tests with `@moduletag :integration` so CI can filter. Ensure new DB queries include data factories from `test/support`. Aim to maintain or improve coverage reported by `mix test --cover`; add regression tests for every bugfix.

## Commit & Pull Request Guidelines
Commits typically follow `type(scope): imperative summary (#issue)` as seen in `git log` (e.g., `fix(secrethub): align cache headers (#705)`). Keep commits focused and reference Jira/GitHub IDs in the summary. Pull requests must describe motivation, list test evidence (`mix test`, manual steps), and link related issues or design docs. Include screenshots or logs when UI/API behavior changes and request reviews from domain owners noted in CODEOWNERS.

## Security & Configuration Tips
Never commit `.env` files or credentials; rely on the provided Docker defaults and override locally via `config/dev.secret.exs`. When touching `scripts/internal_protos.sh` or `pb.gen`, confirm you have VPN + GitHub access before cloning `renderedtext/internal_api`. Validate all scheduler configuration changes against `config/runtime.exs` to avoid breaking production start-up.
