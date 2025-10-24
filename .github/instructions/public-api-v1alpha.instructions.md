---
applyTo: "public-api/v1alpha/**/*"
---
- Read `public-api/v1alpha/AGENTS.md` before changing or reviewing code; it details the Phoenix-style layout under `lib/pipelines_api` and the expectations for tests, naming, and request handling.
- Work inside the Docker dev shell opened with `make console`; from there run `mix deps.get` once and start the service with `iex -S mix` when you need a live node (binds to port 4004).
- Run the suite via `make unit-test` or `mix test`; use `mix test --cover` for API or authorization changes, and rely on `GrpcMock` stubs rather than real downstream services.
- Keep quality gates green: format with `mix format`, lint with `mix credo --strict`, and type-check with `mix dialyzer` (after `mix deps.get && mix compile`).
- Regenerate gRPC clients in `lib/internal_api` with `make pb.gen`; never edit generated files directly.
- Follow the existing commit style (`type(scope): summary`), document touched endpoints and validation commands in PRs, and note any Helm or config follow-up required.
