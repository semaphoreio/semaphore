# Repository Guidelines

## Project Structure & Module Organization
- `lib/` hosts Guard application modules, supervisors, and generated gRPC clients in `lib/internal_api`; re-run `make pb.gen` after proto updates.
- `config/` covers environment configs (`config/{dev,test,prod}.exs`) and runtime secrets; keep credentials in env vars, not source files.
- `test/` mirrors `lib/` with ExUnit suites and helpers in `test/support`; service stubs and golden data live under `fixture/`.
- `priv/`, `templates/`, and `assets/` hold persisted resources, mailer templates, and UI bundles, while `helm/` ships the deployment chart.

## Getting Started & Triage
- Review `DOCUMENTATION.md` for a high-level system map, component triage tips, and debugging entry points before you dive into specific change requests.
- Keep that guide handy when diagnosing incidents or onboarding new contributors; it consolidates architecture, workflows, and configuration dependencies.

## Build, Test, and Development Commands
- `mix deps.get && mix compile` installs dependencies and ensures the code builds.
- `make console.ex` opens `iex -S mix` inside the project container; use `console.bash` when you need a plain shell.
- `make test.ex.setup` provisions Postgres, Redis, and RabbitMQ; run it once before the first test pass.
- `make test.ex [FILE=...]` or `mix test` drives ExUnit; `mix test.watch` keeps a loop running during TDD.
- `mix credo --strict`, `mix format`, and `mix sobelow --config .sobelow-conf` must pass before pushing.

## Coding Style & Naming Conventions
- Always run the Elixir formatter (2-space indentation, max 120 columns) and rely on `.formatter.exs` for the file list.
- Modules stay in `CamelCase`, functions and variables in `snake_case`; generated protobuf code remains untouched.
- Share helpers through `lib/guard/support` or `test/support`, and favour pattern matching plus small pure functions for clarity.

## Testing Guidelines
- Place ExUnit specs next to the code (`*_test.exs`) and organise scenarios with `describe` blocks.
- Reuse factories, Mox doubles, and helpers from `test/support`; keep `fixture/` data deterministic and updated with contract changes.
- Tag slow external calls with `@tag :integration`, supply skip guards, and document any required services in the PR.

## Commit & Pull Request Guidelines
- Follow the existing convention `type(guard): imperative summary (#ticket)` (example: `feat(guard): add team SSO (#660)`).
- Keep commits focused; include migrations or protobuf updates alongside the change and flag remaining work explicitly.
- Pull requests should explain motivation, list validation commands (`make test.ex`, `mix credo`), link Semaphore issues, and attach UI screenshots or config notes when relevant.

## Security & Configuration Tips
- Use the environment block in `Makefile` when running locally and override secrets through exported variables instead of committing changes.
- Before merging, run `mix sobelow --config .sobelow-conf --exit` and review gRPC regen diffs for unintended data exposure.
