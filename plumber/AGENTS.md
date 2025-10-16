# Plumber Stack Agent Notes

Use this file as the high-level triage map for the plumber stack. Each section links to the detailed agent notes that live under `doc/`.

## Quick Map
- `ppl/` – gRPC edge, pipeline/workflow state machines, and RabbitMQ publishers ([doc/ppl/AGENTS.md](doc/ppl/AGENTS.md)).
- `block/` – block lifecycle orchestrator wired to Zebra task events ([doc/block/AGENTS.md](doc/block/AGENTS.md)).
- `definition_validator/` – YAML parsing + schema/semantic validation before scheduling ([doc/definition_validator/AGENTS.md](doc/definition_validator/AGENTS.md)).
- `job_matrix/` – pure library that expands matrix/parallelism definitions into concrete jobs ([doc/job_matrix/AGENTS.md](doc/job_matrix/AGENTS.md)).
- `gofer_client/` – promotions gRPC client used during deploy flows ([doc/gofer_client/AGENTS.md](doc/gofer_client/AGENTS.md)).
- `looper/` – shared STM/periodic worker macros powering `ppl` and `block` schedulers ([doc/looper/AGENTS.md](doc/looper/AGENTS.md)).
- Support stubs: `repo_proxy_ref/` (mock repo-proxy) and `task_api_referent/` (mock Task API) keep local/dev runs hermetic ([doc/repo_proxy_ref/AGENTS.md](doc/repo_proxy_ref/AGENTS.md), [doc/task_api_referent/DOCUMENTATION.md](doc/task_api_referent/DOCUMENTATION.md)).

## End-to-End Flow Scratchpad
1. **Schedule request arrives** → `ppl` gRPC handlers validate YAML via `definition_validator`, expand jobs with `job_matrix`, persist pipeline + block rows, and kick STM workers ([doc/ppl/AGENTS.md](doc/ppl/AGENTS.md)).
2. **Block execution** → `block` STM loopers provision Zebra tasks and watch RabbitMQ for task completion ([doc/block/AGENTS.md](doc/block/AGENTS.md)).
3. **Task lifecycle** → In tests/local, `task_api_referent` simulates Zebra responses so blocks/pipelines advance predictably ([doc/task_api_referent/DOCUMENTATION.md](doc/task_api_referent/DOCUMENTATION.md)).
4. **Promotions** → When promotions are enabled, `gofer_client` notifies Gofer and manages switches; `SKIP_PROMOTIONS` short-circuits locally ([doc/gofer_client/AGENTS.md](doc/gofer_client/AGENTS.md)).
5. **Events** → `ppl` publishers push pipeline/block updates to AMQP exchanges for UI consumers.

## Common Triage Paths
- **Pipeline stuck in `SCHEDULING` / `RUNNING`** → Check `ppl` STM handlers and ensure dependent services (`definition_validator`, `block`, RabbitMQ) respond ([doc/ppl/AGENTS.md](doc/ppl/AGENTS.md)).
- **Block stuck in `RUNNING` / `STOPPING`** → Inspect `block` STM handlers and incoming Zebra events; use RabbitMQ tooling if events seem missing ([doc/block/AGENTS.md](doc/block/AGENTS.md)).
- **Matrix or YAML errors** → Re-run `DefinitionValidator.validate_yaml_string/1` locally to reproduce schema/semantic issues ([doc/definition_validator/AGENTS.md](doc/definition_validator/AGENTS.md)).
- **Promotion failures** → Confirm `SKIP_PROMOTIONS` is set appropriately and inspect `GoferClient` gRPC error tuples ([doc/gofer_client/AGENTS.md](doc/gofer_client/AGENTS.md)).
- **Mock data mismatches** → Update referents (`repo_proxy_ref`, `task_api_referent`) when integration tests need new scenarios ([doc/repo_proxy_ref/AGENTS.md](doc/repo_proxy_ref/AGENTS.md)).

## Command Cheat Sheet
- Bootstrap every app: `mix setup` inside `ppl/`, `block/`, `definition_validator/`, `job_matrix/`, `gofer_client/`, and `looper/`.
- Run targeted tests where the failure originates (e.g. `cd ppl && MIX_ENV=test mix test`) before escalating ([doc/ppl/AGENTS.md](doc/ppl/AGENTS.md), [doc/block/AGENTS.md](doc/block/AGENTS.md)).
- Use `mix credo` routinely on Elixir apps; Looper/library apps are pure so linting catches most regressions ([doc/looper/AGENTS.md](doc/looper/AGENTS.md)).
- Mock services: start `repo_proxy_ref` and `task_api_referent` locally when plumbing end-to-end flows ([doc/repo_proxy_ref/AGENTS.md](doc/repo_proxy_ref/AGENTS.md), [doc/task_api_referent/DOCUMENTATION.md](doc/task_api_referent/DOCUMENTATION.md)).

## Observability + Tooling
- Watchman metrics prefixed with `Ppl.*`, `Block.*`, or `Looper.*` highlight slow handlers (see service-specific notes).
- LogTee tags (`ppl_id`, `block_id`, `task_id`, `request_token`) support cross-service tracing ([doc/ppl/AGENTS.md](doc/ppl/AGENTS.md), [doc/block/AGENTS.md](doc/block/AGENTS.md)).
- RabbitMQ exchanges: `pipeline_state_exchange`, `pipeline_block_state_exchange`, `after_pipeline_state_exchange`, `task_state_exchange`—confirm bindings when events disappear ([doc/ppl/AGENTS.md](doc/ppl/AGENTS.md), [doc/block/AGENTS.md](doc/block/AGENTS.md)).

## Guard Rails (Destructive Ops)
- Never run destructive git commands (`git reset --hard`, `git checkout --`, `git restore` on others' work, etc.) without explicit written approval in the task thread.
- Do not delete or revert files you did not author; coordinate with involved agents first. Moving/renaming is OK after agreement.
- Treat `.env` and environment files as read-only—only the user may edit them.
- Before deleting a file to silence lint/type failures, stop and confirm with the user; adjacent work may be in progress.
- Keep commits scoped to files you changed; list paths explicitly during `git commit`.
- When rebasing, avoid editor prompts (`GIT_EDITOR=:` / `--no-edit`) and never amend commits unless the user requests it.
- After finishing a task, fold any new findings into the relevant `AGENTS.md` or `DOCUMENTATION.md` files—fix mistakes, add context, and preserve useful knowledge while keeping existing valuable guidance intact.

## Reference Index
- Pipelines edge + workflows: [doc/ppl/DOCUMENTATION.md](doc/ppl/DOCUMENTATION.md)
- Block service internals: [doc/block/DOCUMENTATION.md](doc/block/DOCUMENTATION.md)
- YAML validation: [doc/definition_validator/DOCUMENTATION.md](doc/definition_validator/DOCUMENTATION.md)
- Matrix expansion: [doc/job_matrix/DOCUMENTATION.md](doc/job_matrix/DOCUMENTATION.md)
- Promotions client: [doc/gofer_client/DOCUMENTATION.md](doc/gofer_client/DOCUMENTATION.md)
- Worker macros: [doc/looper/DOCUMENTATION.md](doc/looper/DOCUMENTATION.md)
- Repo & Task referents: [doc/repo_proxy_ref/DOCUMENTATION.md](doc/repo_proxy_ref/DOCUMENTATION.md), [doc/task_api_referent/DOCUMENTATION.md](doc/task_api_referent/DOCUMENTATION.md)
