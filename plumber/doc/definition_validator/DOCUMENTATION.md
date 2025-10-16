# Definition Validator

## Overview
Definition Validator validates Semaphore pipeline YAML prior to scheduling. It parses YAML into Elixir maps, verifies schema compliance against the JSON schemas in `spec/`, and enforces additional semantic rules (block dependency graph, promotions). The app is embedded by `ppl` and `block`, but can run stand-alone for linting.

## Responsibilities
- Parse raw YAML (`DefinitionValidator.YamlStringParser`) and provide meaningful error locations.
- Validate YAML structures against JSON schema via `YamlMapValidator` (uses Jesse and the `spec/` schemas bundled in the repo).
- Check higher-level rules not covered by schema (e.g. block dependency DAG is acyclic, promotions configuration sound) through dedicated validators (`PplBlocksDependencies`, `PromotionsValidator`).
- Expose a single API `DefinitionValidator.validate_yaml_string/1` returning either `{:ok, definition_map}` or `{:error, {:malformed, details}}` ready for UI display.

## Architecture
- `DefinitionValidator.Application` starts no persistent processes; the library is used synchronously.
- Validators live in `definition_validator/lib/definition_validator/*` and are pure modules that transform or check maps.
- Schema assets are maintained in the sibling `spec/` app; they are pulled in via Mix dependency and loaded on demand.
- Error formatting (`pretty_print`) reorders error tuples to surface position and message first, easing consumer handling.

## Typical Flow
1. Call `DefinitionValidator.validate_yaml_string(yaml)`.
2. YAML is decoded using `YamlElixir` and normalized.
3. JSON schema validation runs; on failure errors are fed through `pretty_print` so UI layers receive structured tuples (`{:data_invalid, position, message, value, spec}`).
4. Block dependency validator ensures dependencies resolve to existing blocks and the graph is acyclic.
5. Promotions validator verifies promotion targets (switch definitions, required fields).
6. Success returns `{:ok, definition_map}` which downstream services persist or forward.

## Operations
- Install deps: `cd definition_validator && mix setup`.
- Run tests: `cd definition_validator && MIX_ENV=test mix test`.
- Continuous validation for local work: `cd definition_validator && mix test.watch`.
- Lint: `mix credo`.

## Configuration
- No runtime configuration is required; optional `spec` branch selection is achieved by changing the dependency revision.
- The app reads `mix_env` from application env for log verbosity (set in `config/config.exs`).

## Integration Notes
- Consumers (ppl, block) treat any `{:error, {:malformed, ...}}` as hard failures and bubble them back to clients.
- Ensure `spec/` is updated when YAML schema evolves; run the validator test suite to catch regressions.
- All outputs are pure maps/tuples, making the library safe to call from IEx for debugging invalid YAML.
