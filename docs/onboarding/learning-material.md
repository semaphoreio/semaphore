# Onboarding Learning Material (semaphore + saas + toolbox)

This guide is a curated map of where to learn key topics by reading real code in:
- ./ (semaphore)
- ../saas
- ../toolbox

Each section lists concepts, concrete references, and a short exercise.

## Tools and Practices

Concepts
- Service-level setup, conventions, and local workflows.
- Makefiles and scripts as the standard entry points for build, test, and dev.

References
- plumber/ppl/AGENTS.md (service layout, common tasks, commit tags).
- repohub/Makefile (Go workflow: lint, tests, migrations).
- ../toolbox/test-results/Makefile (Go lint and security tooling patterns).
- ../saas/Makefile (shared security checks and docker targets).

Exercise
- Pick one service you will touch in the next month and read its AGENTS.md.
- Run a Makefile target that matches your task (e.g. lint, test, db.migrate) and note required env vars.

## Go: Channels

Concepts
- Buffered vs unbuffered channels.
- Goroutine fan-out with error collection.
- select for timeouts and cancellation.

References
- ../saas/chmura/pkg/nodectrl/ssh.go: Execute() spawns a goroutine, uses a buffered channel, and select with timeout.
- ../saas/chmura/pkg/parallel/process.go: channel used as a semaphore to wait for worker completion.
- ../toolbox/test-results/pkg/cli/cli_test.go: errChan gathers goroutine errors in high fan-out tests.

Exercise
- Trace how Execute() returns on timeout and verify when the SSH connection is closed.
- In parallel.Process, change workers to 1 and explain how job scheduling changes.

## Go: Gorilla (mux and handlers)

Concepts
- Router setup, method filtering, and path parameters.
- Middleware chaining (logging, proxy headers, auth).

References
- ../saas/chmura/pkg/adminapi/server/server.go: mux.NewRouter, route registration, LoggingHandler.
- ../saas/chmura/pkg/adminapi/server/agent.go: mux.Vars to read path params.
- self_hosted_hub/pkg/publicapi/server.go: subrouters, Use(...) middleware chain, handlers.ProxyHeaders.

Exercise
- Find a handler that uses mux.Vars and list every route that supplies those params.
- Add a temporary log line in a handler to inspect a specific header, then remove it.

## Migrator (DB migrations)

Concepts
- golang-migrate CLI usage and migration lifecycle.
- Ecto migration execution in release mode.

References
- repohub/scripts/db.sh: uses migrate -path ... -database ... up.
- repohub/Makefile: db.migration.create and db.migrate targets.
- repohub/Dockerfile: installs golang-migrate binary.
- secrethub/lib/secrethub/migrator.ex: Ecto.Migrator.run with release-style setup.

Exercise
- Follow repohub/db.migrate in Makefile and list every tool it calls.
- Compare the Ecto migrator path source to where migrations live on disk.

## Assertify (assertion libraries in Go)

Note
- No package named "assertify" appears in these repos. Go tests consistently use stretchr/testify's assert and require.

Concepts
- assert.* records a failure and continues.
- require.* fails fast, useful in setup steps.

References
- ../toolbox/test-results/pkg/parser/helpers_test.go: assert.Equal, assert.Nil usage.
- ../toolbox/test-results/pkg/cli/cli_test.go: require.NoError in goroutine fan-out tests.

Exercise
- Convert one assert.Equal to require.Equal and explain the behavioral change.

## Bash and Bats

Concepts
- Bats structure: setup, teardown, @test, run, asserts.
- bats-support and bats-assert helpers.

References
- ../toolbox/tests/test-results.bats: setup/teardown, run, assert_success, assert_output.
- ../toolbox/tests/enetwork.bats: minimal Bats test structure.
- ../toolbox/tests/support/bats-support/load and bats-assert/load: helper libraries.

Exercise
- Add a new Bats test that validates a CLI flag using run + assert_output.

## Ruby and Black-box Testing

Concepts
- Request specs as black-box tests: send HTTP request, assert response and side effects.
- Use fixtures/payloads to simulate real webhook data.

References
- github_hooks/spec/requests/github_hooks_spec.rb: request spec with POST /github and response status assertions.
- github_hooks/spec/controllers/projects_controller_spec.rb: controller-level expectations.

Exercise
- Identify which payload builder is used in github_hooks_spec.rb and find its source.

## Data Encryption

Concepts
- Dedicated encryptor service with gRPC API and a pluggable crypto backend.
- AES-GCM symmetric encryption with per-message random nonce and optional associated data.
- Hybrid encryption in the public API: AES for payload, RSA for key and IV.
- Client-side encrypt/decrypt through internal API stubs, with metrics around success/failure.

References
- encryptor/pkg/api/service.go: Encrypt and Decrypt RPC handlers.
- encryptor/pkg/api/server.go: max message size, recovery handler.
- encryptor/pkg/crypto/encryptor.go: Encryptor interface, NewEncryptor, ENCRYPTOR_AES_KEY handling.
- encryptor/pkg/crypto/aes_gcm_encryptor.go: AES-GCM implementation (nonce prepended to ciphertext).
- encryptor/pkg/crypto/no_op_encryptor.go: no-op backend for local/dev usage.
- ../saas/cachehub/lib/encryptor.ex: gRPC client wrapper, metrics, error handling.
- public-api/v1alpha/lib/pipelines_api/deployments/common.ex: encrypt_data uses AES + RSA and Base64 payload.

Exercise
- Trace how associated_data is supplied in Cachehub.Encryptor.encrypt.
- In pipelines_api/deployments/common.ex, list the steps in encrypt_data in order.
- Follow crypto.NewEncryptor and describe how the encryptor type and key are selected.

## Exception Tracking

Concepts
- Sentry integration through Logger backend, Plug capture, and gRPC interceptors.
- Filtering noisy errors and attaching user context.

References
- hooks_processor/lib/hooks_processor/hooks/grpc/interceptors/sentry_interceptor.ex: capture_message and capture_exception for gRPC.
- hooks_processor/config/runtime.exs: SENTRY_DSN and tags configuration.
- front/lib/front_web/plugs/sentry_context.ex: user context in Sentry events.
- front/lib/front/sentry_event_filter.ex: event filtering example.

Exercise
- Find a Sentry interceptor and list which status codes are captured by default.
- Locate where request_id metadata is attached and confirm it appears in Sentry events.
