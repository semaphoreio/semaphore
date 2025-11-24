# Repository Guidelines

## Project Structure & Module Organization
The repository hosts three Elixir projects. `scheduler/` is the Quantum-based engine that persists and enqueues periodic workflows; its runtime config lives in `scheduler/config/`, business logic in `scheduler/lib/`, tests in `scheduler/test/`, and deployment assets in `scheduler/helm/` and `scheduler/docker-compose.yml`. `definition_validator/` mirrors the standard Mix layout (`lib/`, `config/`, `test/`) and adds Docker-friendly tooling plus deployment manifests. `spec/` stores canonical workflow specifications under `spec/priv/*.yml` and publishes JSON schema artifacts into `spec/publish/`.

## Build, Test, and Development Commands
Run service-specific commands from within each directory:
- `cd scheduler && mix deps.get && mix test` compiles the scheduler and executes the ExUnit suite; run `mix ecto.create && mix ecto.migrate` beforehand to prep the database, or `make test.ex` for the Dockerized CI-equivalent run that also brings up Postgres and RabbitMQ.
- `cd definition_validator && make unit.test` runs the validator tests inside the standard Elixir container, while `make console CMD="mix run --no-halt"` opens an interactive shell with the project mounted.
- `cd spec && make test` executes the Mix tests in the same container wrapper, and `make publish` regenerates the JSON copies of each YAML schema before shipping.

## Coding Style & Naming Conventions
Elixir code uses snake_case filenames, PascalCase modules, and descriptive function names. Format before committing (`mix format`), and lint services that include Credo (`definition_validator/Makefile` exposes `make lint`). Keep schema filenames in `spec/priv` lowercase with hyphenated versions only when mirroring public API names.

## Testing Guidelines
Unit and integration suites rely on ExUnit. Add regression cases under the matching `test/` subtree, group examples with `describe` blocks, and tag slow paths (`@tag :integration`) where useful. For data-dependent scheduler features, seed fixtures through `scheduler/test/support`, and update spec fixtures with `make publish` whenever you change a YAML contract.

## Commit & Pull Request Guidelines
Follow Conventional Commits (e.g., `feat(scheduler): add retry window`). Each pull request should explain the workflow impact, list verification steps (`mix test`, `make unit.test`, `make publish`), and link Semaphore issues. Include logs or screenshots whenever the change alters scheduling behavior or schema output. Keep scopes tight and ensure linters plus relevant `mix test` invocations pass locally before requesting review.

## Security & Configuration Tips
Never commit secrets; instead rely on `.env` files referenced by `docker-compose.yml` or pass credentials through the Make targets. Proto files under `scheduler/lib/internal_api` are generated via `scripts/internal_protos.sh`, so ensure your SSH agent can read `git@github.com:renderedtext/internal_api.git`. Prefer Docker BuildKit (`export DOCKER_BUILDKIT=1`) for reproducible images.
