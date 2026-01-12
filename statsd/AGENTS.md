# Overview
- StatsD container/service built from the `statsd` npm package and configured to ship metrics to Graphite. See: `statsd/package.json`, `statsd/localConfig.js`.
- Runtime is containerized on Node 18.19.0 with Alpine 3.19; the service listens on UDP 8125 and runs `statsd` with `localConfig.js`. See: `statsd/Dockerfile`, `statsd/localConfig.js`.
- Runtime configuration is driven by environment variables such as `FLUSH_INTERVAL`, `GRAPHITE_HOST`, and `DUMP_MESSAGES`. See: `statsd/README.md`, `statsd/localConfig.js`.

# Golden Rules (Must Follow)
- Use the Makefile-driven image workflow (`make pull`, `make build`, `make push`) because CI builds statsd images that way. See: `statsd/Makefile`, `Makefile`, `.semaphore/semaphore.yml`.
- Keep the environment variable interface consistent between config and docs; update both if you change it. See: `statsd/localConfig.js`, `statsd/README.md`.
- Keep CI security checks green: `make check.js.code`, `make check.js.deps`, and `make check.docker` are required. See: `Makefile`, `.semaphore/semaphore.yml`.
- Build production images with `APP_ENV=prod` (default for statsd) to match the CI `runner` target. See: `statsd/Makefile`, `Makefile`, `.semaphore/semaphore.yml`.

# Repo Map (High Level)
- `statsd/Dockerfile` - multi-stage Node/Alpine image; runner stage executes statsd. See: `statsd/Dockerfile`.
- `statsd/docker-compose.yml` - local container wiring, ports, env vars, volume mount. See: `statsd/docker-compose.yml`.
- `statsd/localConfig.js` - StatsD runtime config (ports, backends, env var mapping). See: `statsd/localConfig.js`.
- `statsd/package.json` - npm dependencies (statsd + backends). See: `statsd/package.json`.
- `statsd/Makefile` - service name/env defaults and includes root targets. See: `statsd/Makefile`.
- `statsd/README.md` - env var documentation. See: `statsd/README.md`.
- Main entrypoint is the container command `./node_modules/.bin/statsd localConfig.js`. See: `statsd/Dockerfile`.

# Build, Run, Test
- Prereqs: Docker and docker compose are required for `make build` and the compose workflow. See: `Makefile`, `statsd/docker-compose.yml`.
- Build locally: `make pull` then `make build` (defaults to `APP_ENV=prod` and the `runner` target). See: `statsd/Makefile`, `Makefile`.
- Run locally via compose: `docker compose up --build` exposes UDP 8125 and wires env vars; the service command is `sh`, so start statsd manually with `./node_modules/.bin/statsd localConfig.js` if needed. See: `statsd/docker-compose.yml`, `statsd/Dockerfile`.
- Tests: `npm test` runs Node's built-in test runner for `statsd/test/*.test.js`; `make test` runs the same inside the built image. See: `statsd/package.json`, `statsd/test/localConfig.test.js`, `statsd/test/graphite.integration.test.js`, `statsd/Makefile`.
- CI (main pipeline): statsd builds run `make pull`, `make build`, `make push`, tests run `make test`, then security checks run `make check.js.code`, `make check.js.deps`, and `make check.docker CHECK_DOCKER_OPTS='--skip-dirs node_modules'`. See: `.semaphore/semaphore.yml`.
- CI (daily builds): the daily pipeline repeats the same build + security steps for statsd. See: `.semaphore/daily-builds.yml`.

# Coding Conventions
- `localConfig.js` uses a comma-first object literal style; keep the style consistent for edits. See: `statsd/localConfig.js`.
- Configuration is sourced from `process.env` (e.g., `GRAPHITE_HOST`, `FLUSH_INTERVAL`, `DUMP_MESSAGES`); keep env-based wiring instead of hardcoding values. See: `statsd/localConfig.js`, `statsd/README.md`.
- Graphite backend configuration is explicit (`graphiteHost`, `graphitePort`, `legacyNamespace: false`). See: `statsd/localConfig.js`.

# Dependency & Tooling Management
- Dependencies are managed with npm via `package.json`; the container build runs `npm install`. See: `statsd/package.json`, `statsd/Dockerfile`.
- Node and Alpine versions are pinned via Dockerfile build args (`NODE_VERSION=18.19.0`, `ALPINE_VERSION=3.19`). See: `statsd/Dockerfile`.

# Database / Storage (if applicable)
- No database or migration tooling is configured in this service; it is a StatsD daemon shipping metrics to Graphite. See: `statsd/localConfig.js`, `statsd/README.md`.

# Observability / Debugging
- Debug logging is enabled (`debug: true`), and `DUMP_MESSAGES=true` prints every UDP message. See: `statsd/localConfig.js`, `statsd/README.md`.
- Flush interval is controlled by `FLUSH_INTERVAL` (milliseconds) and defaults to 60000 in compose. See: `statsd/localConfig.js`, `statsd/README.md`, `statsd/docker-compose.yml`.
- The runtime image installs `netcat-openbsd` and `tcpdump` for in-container troubleshooting. See: `statsd/Dockerfile`.

# Security / Compliance
- Container runs as non-root `nobody` and owns `/app`. See: `statsd/Dockerfile`.
- CI security scans are mandatory for JS code, dependencies, and the Docker image. See: `Makefile`, `.semaphore/semaphore.yml`.
- Runtime configuration is injected via environment variables; keep sensitive values out of source files. See: `statsd/docker-compose.yml`, `statsd/localConfig.js`.

# PR Checklist
- `make pull` and `make build` succeed for the statsd image. See: `statsd/Makefile`, `Makefile`, `.semaphore/semaphore.yml`.
- `make test` (or `npm test`) passes. See: `statsd/Makefile`, `statsd/package.json`, `statsd/test/graphite.integration.test.js`.
- `make check.js.code` and `make check.js.deps` pass. See: `Makefile`, `.semaphore/semaphore.yml`.
- `make check.docker CHECK_DOCKER_OPTS='--skip-dirs node_modules'` passes after a build. See: `Makefile`, `.semaphore/semaphore.yml`.
- If runtime env vars change, update both `localConfig.js` and the README env var list. See: `statsd/localConfig.js`, `statsd/README.md`.
- Validate compose wiring if ports or env vars change (`8125/udp`, `FLUSH_INTERVAL`, `GRAPHITE_HOST`, `PREFIX`). See: `statsd/docker-compose.yml`.
