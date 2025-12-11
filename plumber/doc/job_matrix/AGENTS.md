# Job Matrix Agent Notes

## Essentials
- Validation entry: `JobMatrix.Validator.validate/1` (returns `{:ok, _}` or `{:error, {:malformed, message}}`).
- Expansion entry: `JobMatrix.Handler.expand_job/1` (turns a job map with `matrix` key into a list of job variants).
- Parallelism shorthand: `JobMatrix.ParallelismHandler.parallelize_jobs/1` converts `parallelism: N` into matrix/env vars.
- Cartesian builder: `JobMatrix.Cartesian.product/3` and `JobMatrix.Transformer.to_env_vars_list/1` produce env-var combinations.

## Quick Commands
- Install deps: `cd job_matrix && mix deps.get` (or `mix setup`).
- Run tests: `mix test` (covers validator, transformer, handler, parallelism).
- Lint: `mix credo`.

## Debug Tips
- Capture `{ :error, {:malformed, msg} }` to bubble user-friendly errors; avoid raising.
- When job names look odd, inspect `JobMatrix.Handler` name-generation logic (adds suffix describing env var values or index/count pairs).
- Duplicate axis names trigger `Duplicate name` errors—ensure YAML block defines unique `env_var`/`software` keys.
- Parallelism path injects `SEMAPHORE_JOB_INDEX` and `SEMAPHORE_JOB_COUNT` env vars; verify downstream relies on them before changing.

## Integration Notes
- Library is pure; no processes to supervise. Safe to use in tests and compile-time.
- Update both validator and transformer when extending matrix syntax.
- Consumers typically call validator first, then handler; keep that sequence to prevent `throw` propagation.
