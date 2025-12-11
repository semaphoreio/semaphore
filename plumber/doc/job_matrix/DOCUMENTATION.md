# Job Matrix Service

## Overview
`job_matrix` is a library application that expands a job's matrix/parallelism definition into concrete job variants. It converts YAML block definitions into explicit job maps with environment variables, validates matrix syntax, and is used by both `ppl` and `block` before persisting jobs or scheduling builds.

## Responsibilities
- Validate matrix definitions supplied in a job (`JobMatrix.Validator`).
- Convert matrix axes to environment-variable combinations using cartesian products (`JobMatrix.Cartesian`, `JobMatrix.Transformer`).
- Generate derived jobs with expanded env vars and unique names (`JobMatrix.Handler`).
- Support the legacy `parallelism` shortcut for creating `SEMAPHORE_JOB_INDEX`/`SEMAPHORE_JOB_COUNT` environment variables (`JobMatrix.ParallelismHandler`).

## Architecture
- Pure functional modules; no supervision tree or runtime processes.
- Entry points:
  - `JobMatrix.Handler.expand_job/1` (called from block scheduler to expand `matrix` definitions).
  - `JobMatrix.ParallelismHandler.parallelize_jobs/1` (mutates blocks by turning `parallelism` into a 1D matrix).
  - `JobMatrix.Validator.validate/1` (ensures schema correctness; reused by `definition_validator`).
- The cartesian builder works on `%{"env_var" => "FOO", "values" => [...]}` and `%{"software" => "BAR", "versions" => [...]}` axes.

## Data Flow
1. Definition validator ensures `matrix` fields are well shaped.
2. `JobMatrix.Handler` receives a job map, validates the matrix, obtains env var combinations, and clones the job per combination.
3. Each generated job receives concatenated env vars, with names suffixes reflecting the matrix values or counts.
4. For `parallelism: N`, handler generates `matrix = SEMAPHORE_JOB_INDEX 1..N` and injects `SEMAPHORE_JOB_COUNT`.

## Error Handling
- Validation throws `{:malformed, message}` tuples when matrix structure is invalid (non-list, missing keys, duplicate axis names, empty value lists).
- Handler catches thrown errors and propagates them upward; callers translate results into gRPC/HTTP errors.

## Operations
- Install deps: `cd job_matrix && mix deps.get` (or `mix setup`).
- Run tests: `mix test` (covering transformer, validator, parallelism).
- Used purely as a dependency; no application start required beyond compile.

## Integration Notes
- The library returns either `{ :ok, jobs }` or `{ :error, reason }`; consumers must handle tuples, not exceptions.
- Ensure new YAML syntax updates keep validator/transformer modules in sync.
- When extending axis syntax, add cases in both `Validator` and `Transformer` and update tests.
