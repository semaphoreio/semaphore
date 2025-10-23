# Definition Validator Agent Notes

## Core Pieces
- Entry point: `DefinitionValidator.validate_yaml_string/1`.
- Parsers: `YamlStringParser` (YAML -> map), `YamlMapValidator` (schema via Jesse), `PplBlocksDependencies` (DAG checks), `PromotionsValidator` (promotion semantics).
- Schema source: `spec/` dependency contains JSON schema files per YAML version.

## Handy Commands
- Install deps: `cd definition_validator && mix setup`.
- Run suite: `mix test` (uses fixture YAML under `test/fixtures`).
- Watch mode: `mix test.watch` while editing schemas or validators.
- Linting: `mix credo`.

## Debug Tips
- Capture returned error tuples to surface line/column: `DefinitionValidator.validate_yaml_string(File.read!(
