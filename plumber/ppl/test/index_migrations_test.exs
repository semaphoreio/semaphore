defmodule Ppl.IndexMigrationsTest do
  @moduledoc """
  Indexes from the 20261016* and 20261020120000 migrations: they must have the
  expected definitions, and rerunning a migration must fail on an INVALID
  index instead of silently skipping it.
  """
  use ExUnit.Case

  alias Ppl.EctoRepo, as: Repo
  alias Ppl.EctoRepo.Migrations.AddTimeLimitsStateIndex

  # Not a real migration version: used to rerun a migration's up/0 without
  # touching the recorded history.
  @rerun_version 99_990_101_000_000

  @definitions [
    {"index_latest_workflows_on_wf_id",
     "CREATE INDEX index_latest_workflows_on_wf_id ON public.latest_workflows USING btree (wf_id)"},
    {"index_time_limits_on_state",
     "CREATE INDEX index_time_limits_on_state ON public.time_limits USING btree (state)"},
    {"index_pipeline_requests_on_org_and_inserted_at_expiring",
     "CREATE INDEX index_pipeline_requests_on_org_and_inserted_at_expiring ON public.pipeline_requests USING btree (((request_args ->> 'organization_id'::text)), inserted_at) WHERE (expires_at IS NOT NULL)"},
    {"index_pipeline_blocks_on_waiting",
     "CREATE INDEX index_pipeline_blocks_on_waiting ON public.pipeline_blocks USING btree (id) WHERE ((state)::text = 'waiting'::text)"}
  ]

  @migration_file "priv/ecto_repo/migrations/20261016120001_add_time_limits_state_index.exs"

  setup_all do
    # Migrations live in priv and are not compiled with the app.
    unless Code.ensure_loaded?(AddTimeLimitsStateIndex), do: Code.require_file(@migration_file)
    :ok
  end

  test "indexes exist, are valid and have the expected definitions" do
    for {name, definition} <- @definitions do
      assert index_def(name) == definition
      assert valid?(name), "#{name} is not valid"
    end
  end

  describe "rerunning a migration" do
    setup do
      on_exit(fn ->
        set_valid("index_time_limits_on_state", true)
        forget_rerun()
      end)
    end

    test "is a no-op when the index already exists and is valid" do
      assert :ok == rerun(AddTimeLimitsStateIndex)
      assert valid?("index_time_limits_on_state")
    end

    test "fails when the index exists but is INVALID" do
      set_valid("index_time_limits_on_state", false)

      error = assert_raise Postgrex.Error, fn -> rerun(AddTimeLimitsStateIndex) end
      assert error.postgres.message =~ "index_time_limits_on_state is INVALID"
      refute recorded?()
    end
  end

  defp rerun(migration), do: Ecto.Migrator.up(Repo, @rerun_version, migration, log: false)

  defp recorded? do
    %{rows: rows} =
      Repo.query!("SELECT 1 FROM schema_migrations WHERE version = $1", [@rerun_version])

    rows != []
  end

  defp forget_rerun,
    do: Repo.query!("DELETE FROM schema_migrations WHERE version = $1", [@rerun_version])

  # Flipping pg_index needs a superuser, as the test database user is in docker
  # compose and CI.
  defp set_valid(name, valid) do
    Repo.query!("UPDATE pg_index SET indisvalid = $1 WHERE indexrelid = to_regclass($2)", [
      valid,
      name
    ])
  end

  defp index_def(name) do
    %{rows: [[definition]]} =
      Repo.query!("SELECT indexdef FROM pg_indexes WHERE indexname = $1", [name])

    definition
  end

  defp valid?(name) do
    %{rows: [[valid]]} =
      Repo.query!("SELECT indisvalid FROM pg_index WHERE indexrelid = to_regclass($1)", [name])

    valid
  end
end
