# System Overview
- Statsd is a containerized StatsD daemon that aggregates UDP metrics and forwards them to a Graphite sink, using the `statsd` npm package and `localConfig.js`. See: `statsd/package.json`, `statsd/localConfig.js`, `statsd/README.md`.
- Deployment is via a Docker image built from `statsd/Dockerfile` and orchestrated locally with `docker-compose.yml`; CI builds and security checks are defined in Semaphore pipelines. See: `statsd/Dockerfile`, `statsd/docker-compose.yml`, `.semaphore/semaphore.yml`.
- Scope note: this document maps only the `statsd/` service in a larger multi-service repository; other services are not covered here. See: `.semaphore/semaphore.yml`.

# Architecture Diagram (Text)
```
UDP clients
  |
  |  UDP 8125
  v
statsd container (node + statsd)
  |  flushInterval -> Graphite backend
  v
Graphite (GRAPHITE_HOST:2003)
```
See: `statsd/localConfig.js`, `statsd/Dockerfile`, `statsd/docker-compose.yml`.

# Components
## Statsd container
- Location (paths): `statsd/` (Dockerfile, config, compose, npm package). See: `statsd/Dockerfile`, `statsd/localConfig.js`, `statsd/package.json`.
- Responsibilities: receive UDP metrics on port 8125, aggregate, and flush to Graphite; optional verbose message dump for debugging. See: `statsd/localConfig.js`, `statsd/README.md`.
- Entry points: container CMD runs `./node_modules/.bin/statsd localConfig.js`; docker-compose overrides command to `sh` for interactive use. See: `statsd/Dockerfile`, `statsd/docker-compose.yml`.
- Key modules: `statsd/localConfig.js` (runtime config), `statsd/package.json` (dependencies), `statsd/Dockerfile` (image/runtime), `statsd/Makefile` (build targets). See: `statsd/localConfig.js`, `statsd/package.json`, `statsd/Dockerfile`, `statsd/Makefile`.
- Data stores used: none configured in this repo; StatsD state is in-memory within the upstream `statsd` package (Unknown / verify). See: `statsd/package.json`.
- External dependencies: Graphite host/port (`GRAPHITE_HOST`, `graphitePort: 2003`); npm packages `statsd`, `statsd-librato-backend`, `statsd-influxdb-backend`; runtime tools `netcat-openbsd` and `tcpdump` installed in the image. See: `statsd/localConfig.js`, `statsd/package.json`, `statsd/Dockerfile`.
- How it communicates: listens on UDP port 8125; forwards metrics to Graphite backend at `GRAPHITE_HOST:2003` (protocol unspecified here; verify in upstream statsd). See: `statsd/localConfig.js`, `statsd/docker-compose.yml`.
- Extension points: edit `statsd/localConfig.js` for backends and config; add/change env vars in `statsd/README.md` and `statsd/docker-compose.yml`; add npm dependencies in `statsd/package.json`. See: `statsd/localConfig.js`, `statsd/README.md`, `statsd/docker-compose.yml`, `statsd/package.json`.
- Gotchas: `docker-compose` uses `command: "sh"` so statsd does not start automatically in that mode; `DUMP_MESSAGES=true` is very noisy; `graphiteHost` is read from env and may be unset (Unknown / verify behavior when missing). See: `statsd/docker-compose.yml`, `statsd/README.md`, `statsd/localConfig.js`.

# Data Model & Persistence
- No database, schema, or migration files exist under `statsd/`; metrics aggregation is handled by the upstream `statsd` package in memory (Unknown / verify internal structures). See: `statsd/package.json`, `statsd/localConfig.js`.

# Request / Job Flows
- Container startup and config load: container runs `statsd localConfig.js` -> statsd reads env-backed config -> binds to UDP port 8125. See: `statsd/Dockerfile`, `statsd/localConfig.js`, `statsd/docker-compose.yml`.
- Metric ingestion and flush: client sends UDP metrics to 8125 -> statsd aggregates -> flushes to Graphite backend at `GRAPHITE_HOST:2003` on `flushInterval`. See: `statsd/localConfig.js`, `statsd/docker-compose.yml`, `statsd/README.md`.
- Debug message dump: when `DUMP_MESSAGES=true`, statsd prints every received UDP message. See: `statsd/localConfig.js`, `statsd/README.md`.
- CI security checks (job flow): on changes in `statsd/`, CI builds and pushes image, then runs `make check.js.code`, `make check.js.deps`, and `make check.docker`. See: `.semaphore/semaphore.yml`, `Makefile`, `statsd/Makefile`.

# Configuration & Environments
- Runtime configuration lives in `statsd/localConfig.js` and is primarily env-driven (`GRAPHITE_HOST`, `FLUSH_INTERVAL`, `DUMP_MESSAGES`); defaults come from docker-compose for local runs. See: `statsd/localConfig.js`, `statsd/README.md`, `statsd/docker-compose.yml`.
- Build-time configuration uses Dockerfile args for `NODE_VERSION` and `ALPINE_VERSION`. See: `statsd/Dockerfile`.
- Config precedence beyond env overrides is not defined here (Unknown / verify in upstream statsd docs). See: `statsd/localConfig.js`.

# Infrastructure & Deployment (as implemented here)
- Docker image: multi-stage build with `base`, `dev`, and `runner` targets; runner runs as `nobody`, exposes UDP 8125, and executes statsd. See: `statsd/Dockerfile`.
- Local runtime: `docker-compose.yml` builds the `runner` target, maps UDP 8125, sets env defaults, and mounts the working directory. See: `statsd/docker-compose.yml`.
- Build tooling: `statsd/Makefile` includes the repository root `Makefile` targets (`make build`, `make pull`, `make push`). See: `statsd/Makefile`, `Makefile`.
- CI: Semaphore pipeline blocks for statsd handle image build/push and security checks; daily builds repeat these steps. See: `.semaphore/semaphore.yml`, `.semaphore/daily-builds.yml`.

# Testing Strategy (as implemented here)
- Node's built-in test runner executes unit and integration tests in `statsd/test/*.test.js`. See: `statsd/package.json`, `statsd/test/localConfig.test.js`, `statsd/test/graphite.integration.test.js`.
- Integration coverage includes Graphite flush behavior by spawning statsd and asserting emitted lines. See: `statsd/test/graphite.integration.test.js`.
- CI runs `make test` for statsd and also validates JS code/dependencies and the Docker image via security tooling. See: `.semaphore/semaphore.yml`, `statsd/Makefile`, `Makefile`.

# Observability
- Runtime logging is controlled by `debug: true` and `dumpMessages` (via `DUMP_MESSAGES`); verbose logging is expected when enabled. See: `statsd/localConfig.js`, `statsd/README.md`.
- No tracing or external logging libraries are configured in this repo (Unknown / verify in upstream `statsd` package). See: `statsd/package.json`.

# “How to Extend” Playbooks
- Add a new config option (env-backed):
  - Update `statsd/localConfig.js` to read the new `process.env` value and apply it to the statsd config. See: `statsd/localConfig.js`.
  - Document the new env var in `statsd/README.md`. See: `statsd/README.md`.
  - If the option needs a local default, add it to `statsd/docker-compose.yml`. See: `statsd/docker-compose.yml`.
- Add or switch a backend:
  - Add/update the backend dependency in `statsd/package.json` (if not already present). See: `statsd/package.json`.
  - Update `backends` and backend-specific settings in `statsd/localConfig.js`. See: `statsd/localConfig.js`.
  - Update env var documentation in `statsd/README.md` and defaults in `statsd/docker-compose.yml` if needed. See: `statsd/README.md`, `statsd/docker-compose.yml`.

# Appendix: Index of Important Files
- `statsd/Dockerfile` - image build stages and runtime entrypoint for statsd.
- `statsd/localConfig.js` - statsd runtime configuration and env var mapping.
- `statsd/README.md` - environment variable documentation.
- `statsd/package.json` - npm dependencies and scripts.
- `statsd/docker-compose.yml` - local runtime wiring and defaults.
- `statsd/Makefile` - statsd-specific build settings, includes root Makefile.
- `statsd/test/localConfig.test.js` - validates localConfig defaults and env parsing.
- `statsd/test/graphite.integration.test.js` - verifies statsd flushes metrics to Graphite.
- `Makefile` - shared build and security check targets used by statsd CI.
- `.semaphore/semaphore.yml` - main CI pipeline including statsd build and security checks.
- `.semaphore/daily-builds.yml` - daily pipeline with statsd build and security checks.
