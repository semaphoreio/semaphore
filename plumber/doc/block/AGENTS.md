# Block Agent Notes

## Quick Map
- Supervision root: `Block.Application` starts `Block.EctoRepo`, `Block.Sup.STM`, and `Block.Tasks.TaskEventsConsumer`.
- State machines live in `block/lib/block/{blocks,tasks}/stm_handler/`; each module wraps a Looper worker that polls and advances rows.
- Persistence: PostgreSQL schema under `block/priv/ecto_repo/migrations`; repo module is `Block.EctoRepo`.
- RabbitMQ: consumer binds to `task_state_exchange` (routing key `finished`).

## Daily Commands
- Setup (deps + DB): `cd block && mix setup`.
- Run migrations only: `cd block && mix ecto.migrate`.
- Tests: `cd block && MIX_ENV=test mix test` (DB wiped automatically).
- Console: `cd block && iex -S mix` (ensure `RABBITMQ_URL` and database env vars set).

## Debug Pointers
- Task stuck RUNNING? Inspect `Block.Tasks.STMHandler.RunningState` logic and confirm RabbitMQ event arrived. Use `rabbitmqadmin get queue=task_state_exchange.finished` for inspection.
- Blocks not spawning tasks? Check the `Block.CodeRepo` command reader – invalid YAML results propagate from `definition_validator`.
- STOPPING never finishes? Verify callbacks `:compile_task_done_notification_callback` / `:after_ppl_task_done_notification_callback` in config; missing modules will raise `apply/3` errors.
- Database drift? Compare schema with latest migrations and rerun `mix ecto.migrate` (test env uses sandbox DB `block_test`).

## Env Vars
- `RABBITMQ_URL` – required for AMQP consumer/publishers.
- `COMPILE_TASK_DONE_NOTIFICATION_CALLBACK`, `AFTER_PPL_TASK_DONE_NOTIFICATION_CALLBACK` – MFA tuples as `{Module, :function}`; defaults log warnings when unset.

Keep this close when triaging block execution or termination flows.
