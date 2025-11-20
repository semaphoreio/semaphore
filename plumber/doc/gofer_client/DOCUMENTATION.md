# Gofer Client

## Overview
Gofer Client is a thin gRPC wrapper around the Gofer promotions service. It provisions promotion switches, notifies Gofer when pipelines finish, and verifies deployment target access. The library is consumed by `ppl` during promotion flows.

## Responsibilities
- Format protobuf requests for Gofer RPCs (`RequestFormatter`).
- Maintain gRPC channels to the Gofer service (`GrpcClient`).
- Parse responses into simple Elixir tuples (`ResponseParser`).
- Allow promotion flows to be bypassed locally via `SKIP_PROMOTIONS`.

## Architecture
- `GoferClient` exposes three public functions: `create_switch/4`, `pipeline_done/3`, and `verify_deployment_target_access/4`.
- `GoferClient.Application` supervises the gRPC connection workers (host/port defined in `config/*.exs`).
- Request/response formatting lives in dedicated modules so they can be unit tested without hitting Gofer.
- Test support mocks Gofer via `grpc_mock` to keep CI hermetic.

## Interaction Points
1. **Switch creation** – serialises YAML definition, previous artefact IDs, and ref args into `InternalApi.Gofer.CreateSwitchRequest` before dispatching to Gofer.
2. **Pipeline done notification** – informs Gofer when a promoted pipeline finishes so switches can advance or unlock.
3. **Deployment target access** – checks if the triggerer is authorised to deploy to a guarded environment before scheduling promotions.

## Configuration
- `SKIP_PROMOTIONS` (`true`/`false`) – when true all public functions short-circuit to `{:ok, ""}`.
- `GOFER_GRPC_HOST`, `GOFER_GRPC_PORT`, and TLS parameters – set in `config/{dev,test,prod}.exs`; defaults point to docker-compose services.
- Timeout/retry settings live in `config/config.exs` under the `GoferClient.GrpcClient` key.

## Operations
- Install deps: `cd gofer_client && mix setup` (alias pulls deps only).
- Run tests: `mix test` (mocks gRPC calls by default).
- Lint: `mix credo`.
- Connect to a real Gofer instance by exporting the host/port env vars and ensuring network reachability.

## Failure Modes
- Network errors bubble up as `{:error, reason}`; callers in `ppl` decide whether to retry or skip promotions.
- Gofer validation failures are returned as `{:error, {:gofer, status, message}}` by `ResponseParser` and should be surfaced to users.
