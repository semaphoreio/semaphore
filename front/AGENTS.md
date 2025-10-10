# Repository Guidelines

## Project Structure & Module Organization
- `lib/` holds Phoenix contexts, controllers, and services; shared helpers sit in `test/support`.
- `assets/` hosts the Preact/TypeScript UI alongside the build scripts (`build.js`, `package.json`).
- `config/` tracks environment settings, while runtime secrets are read from sibling files in `env/`.
- `test/` mirrors `lib/` with ExUnit suites, Wallaby browser specs in `test/browser`, and fixtures under `test/fixture`.
- `priv/` serves runtime assets, and `workflow_templates/` supplies seeded YAML pipelines consumed by the UI.

## Build, Test, and Development Commands
- First-time setup: `mix deps.get` and `npm install --prefix assets`.
- `make dev.server` (Docker) launches Phoenix with Redis, RabbitMQ, and demo data preloaded.
- `mix phx.server` runs on the host once services are already up via `docker compose up -d`.
- `mix test` runs backend suites; `make test.js` or `npm test --prefix assets` covers frontend logic.
- Keep `mix credo --strict`, `mix format`, and `npm run lint` clean before pushing.
- Bundle production assets with `mix assets.deploy`.

## Coding Style & Naming Conventions
- Format Elixir with `mix format`; favor pipe-first flows and 2-space indentation.
- Credo (`config/.credo.exs`) runs in strict mode—fix findings instead of disabling checks.
- Modules follow `Front.Foo` naming and live in `snake_case` paths; tests are co-located as `*_test.exs`.
- TypeScript components use PascalCase filenames; reusable helpers belong under `assets/js/` and tests under `*.spec.ts`.

## Testing Guidelines
- Keep unit tests close to their modules and name `describe` blocks after the function under test.
- Wallaby browser specs need the Docker stack running; execute with `mix test test/browser`.
- Generate coverage with `mix coveralls.html` and `npm run coverage`.
- Update fixtures in `test/fixture` when workflow, API, or UI contracts change.

## Commit & Pull Request Guidelines
- Commits follow `type(scope): message (#issue)` (e.g., `fix(front): adjust mermaid rendering (#621)`).
- Each commit should bundle code, schema, and tests for a single concern.
- PRs summarize impact, list manual checks, link tracking items, and add UI screenshots when relevant.
- Verify CI (mix, JS lint, tests) is green before requesting review and call out any external dependencies.

## Environment & Services
- Shared defaults live in `env/`; do not commit developer-specific overrides.
- Use Docker (via `make dev.server` or `docker compose up`) to run RabbitMQ, Redis, and API stubs before starting Phoenix.
- Validate YAML pipelines with `scripts/check-templates.sh <path>` prior to committing.
- Maintain security suppressions in `security-ignore-policy.rego` with a short inline rationale.
