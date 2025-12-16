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
- Prefer the helpers in `Support.Browser`/`Support.Browser.Assertions` (`assert_stable/2`, `assert_flash_notice/2`, etc.) instead of calling `assert_text/2` or `assert_has/2` directly—these wrappers handle stale DOM retries and should be the default in new tests.
- When a flow depends on flashes or full-page redirects, assert against deterministic selectors (e.g., `#changes-notification p[data-test=...]`) rather than generic text nodes, and wait for the new page before chaining more actions.
- Seed every browser test with the features and permissions it needs (usually via `Support.Stubs.Feature.enable_feature/3` and `Support.Stubs.PermissionPatrol.allow_everything/2`) so the UI renders the buttons you intend to click.
- Keep destructive test fixtures scoped: create orgs/projects/users per test module using the stubs in `test/support/stubs`, and add explicit waits if a change propagates asynchronously (e.g., retention policies or self-hosted agents).
- Generate coverage with `mix coveralls.html` and `npm run coverage`.
- Update fixtures in `test/fixture` when workflow, API, or UI contracts change.

## Browser Testing Notes
- Use the `browser_test` macro from `FrontWeb.WallabyCase` for every Wallaby spec. It handles screenshot capture, session cleanup, and tags so failures are easier to debug.
- Chrome/Chromedriver now refuse to click invisible elements; always wait until the target button/link is visible (`assert_stable/2`, `assert_stable_text/2`) before clicking, and prefer selectors that match the final rendered node (not a parent wrapper).
- For modals, redirects, and flash messages, re-sync the page via `Support.Browser.assert_flash_notice/2` or another deterministic element to avoid stale references after navigation.

## Commit & Pull Request Guidelines
- Commits follow `type(scope): message (#issue)` (e.g., `fix(front): adjust mermaid rendering (#621)`).
- First line must be 50 characters or less.
- Each subsequent line should describe a feature tagged with `[type]` where type is one of: `ui`, `worker`, `ci`, `api`, `db`, `config`, `docs`, `test`.
- Each commit should bundle code, schema, and tests for a single concern.
- PRs summarize impact, list manual checks, link tracking items, and add UI screenshots when relevant.
- Verify CI (mix, JS lint, tests) is green before requesting review and call out any external dependencies.

## Environment & Services
- Shared defaults live in `env/`; do not commit developer-specific overrides.
- Use Docker (via `make dev.server` or `docker compose up`) to run RabbitMQ, Redis, and API stubs before starting Phoenix.
- Validate YAML pipelines with `scripts/check-templates.sh <path>` prior to committing.
- Maintain security suppressions in `security-ignore-policy.rego` with a short inline rationale.
