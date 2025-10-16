# Task API Referent

## Overview
`task_api_referent` is a mock implementation of Semaphore's Task API. It is used in integration tests to simulate Zebra behaviour when plumber schedules, monitors, or terminates tasks. The referent exposes the same gRPC surface that plumber expects, but persists data in memory for deterministic behaviour.

## Responsibilities
- Provide `schedule`, `describe_many`, and `terminate` operations compatible with InternalApi.Task messages.
- Maintain an in-memory representation of tasks/jobs to support idempotency and termination flows during tests.
- Log scheduling metadata for debugging (`LogTee` integration) and surface validation errors with descriptive messages.

## Architecture
- `TaskApiReferent.Application` starts the necessary supervision tree (in-memory stores, gRPC server).
- Core logic lives in `TaskApiReferent.Actions`:
  - Validates payloads via `TaskApiReferent.Validation`.
  - Delegates persistence to `TaskApiReferent.Service`.
  - Schedules asynchronous execution using `TaskApiReferent.Runner`.
- The module raises `GRPC.RPCError` for not-found or invalid parameter scenarios, matching behaviour of the real service.

## Usage Patterns
- Plumber tests depend on the referent to simulate scheduling success, duplicates (via `request_token`), and termination callbacks.
- Docker compose setups start this service so local plumber runs can exercise Task API without Zebra.
- Validation helpers format nested job data for logging, aiding inspection when a schedule fails.

## Operations
- Setup: `cd task_api_referent && mix deps.get` (or `mix setup`).
- Run tests: `mix test` (covers actions, validation, runner).
- Start locally: `iex -S mix` (port configured in `config/config.exs`).
- Smoke test: `grpcurl -plaintext localhost:<port> InternalApi.Task.TaskService.DescribeMany -d '{"task_ids":["..."]}'`.

## Extending
- When adding new Task API features, update `TaskApiReferent.Actions` and mirror behaviour in the referent's service layer.
- Ensure validations stay in sync with real Task API contracts; adjust `Validation` module and tests concurrently.
- Use descriptive LogTee messages to ease debugging of integration scenarios.
