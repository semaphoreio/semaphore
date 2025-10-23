# Gofer Client Agent Notes

## Essentials
- Public API: `create_switch/4`, `pipeline_done/3`, `verify_deployment_target_access/4`.
- Transport: `GoferClient.GrpcClient` wraps `GRPC.Stub` with connection pooling.
- Formatters: `RequestFormatter` builds protobuf structs, `ResponseParser` unwraps responses/errors.
- Feature flag: `SKIP_PROMOTIONS=true` bypasses outbound calls (used in dev/tests).

## Commands
- Setup deps: `cd gofer_client && mix setup`.
- Run tests: `mix test` (uses `grpc_mock` to fake Gofer).
- Credo lint: `mix credo`.
- Exercise manually: `SKIP_PROMOTIONS=false iex -S mix` then call helper functions with sample YAML maps.

## Debug Tips
- Verify host/port via `Application.get_env(:gofer_client, GoferClient.GrpcClient)`.
- gRPC error tuples come back as `{:error, GRPC.RPCError}`; inspect `error.status` and `error.message`.
- Promotions hanging? Check `SKIP_PROMOTIONS`, ensure Gofer is reachable, and confirm TLS cert paths in `config/runtime.exs`.
- Request formatting failures usually mean YAML map lacks promotion data; see `RequestFormatter.form_create_request/4`.

## Integration
- Library does not supervise retries—callers (`ppl`) must decide how to handle failure.
- When adding new Gofer RPCs, follow the same pattern: format -> client -> parser, and extend tests with mocked responses.
