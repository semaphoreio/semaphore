defmodule Audit.IndexMigrationsTest do
  use ExUnit.Case

  alias Audit.Repo
  alias Audit.Repo.Migrations.AddOrgIdStreamedTimestampIndexToEvents, as: Migration
  alias Ecto.Adapters.SQL.Sandbox

  @index "events_org_id_streamed_timestamp_index"
  @migration_file "priv/repo/migrations/20261124120000_add_org_id_streamed_timestamp_index_to_events.exs"

  # Not a real migration version: reruns up/0 without touching recorded history.
  @rerun_version 99_990_101_000_000

  setup_all do
    unless Code.ensure_loaded?(Migration), do: Code.require_file(@migration_file)
    :ok
  end

  setup do
    on_exit(fn ->
      unboxed(fn ->
        set_valid(true)
        Repo.query!("DELETE FROM schema_migrations WHERE version = $1", [@rerun_version])
      end)
    end)
  end

  test "index exists, is valid and covers (org_id, streamed, timestamp)" do
    unboxed(fn ->
      assert index_def() ==
               "CREATE INDEX #{@index} ON public.events USING btree (org_id, streamed, \"timestamp\")"

      assert valid?()
    end)
  end

  test "rerunning is a no-op when the index already exists and is valid" do
    unboxed(fn ->
      assert :ok == rerun()
      assert valid?()
      assert index_count() == 1
    end)
  end

  test "rerunning fails when the index exists but is INVALID" do
    unboxed(fn ->
      set_valid(false)

      error = assert_raise Postgrex.Error, fn -> rerun() end
      assert error.postgres.message =~ "#{@index} is INVALID"
      refute recorded?()
    end)
  end

  # CREATE INDEX CONCURRENTLY cannot run inside the sandbox transaction.
  defp unboxed(fun), do: Sandbox.unboxed_run(Repo, fun)

  defp rerun, do: Ecto.Migrator.up(Repo, @rerun_version, Migration, log: false)

  defp recorded? do
    %{rows: rows} =
      Repo.query!("SELECT 1 FROM schema_migrations WHERE version = $1", [@rerun_version])

    rows != []
  end

  # Flipping pg_index needs a superuser, which the test database user is.
  defp set_valid(valid) do
    Repo.query!("UPDATE pg_index SET indisvalid = $1 WHERE indexrelid = to_regclass($2)", [
      valid,
      @index
    ])
  end

  defp index_def do
    %{rows: [[definition]]} =
      Repo.query!("SELECT indexdef FROM pg_indexes WHERE indexname = $1", [@index])

    definition
  end

  defp index_count do
    %{rows: [[count]]} =
      Repo.query!(
        "SELECT count(*) FROM pg_indexes WHERE tablename = 'events' AND indexdef LIKE '%(org_id, streamed, \"timestamp\")'"
      )

    count
  end

  defp valid? do
    %{rows: [[valid]]} =
      Repo.query!("SELECT indisvalid FROM pg_index WHERE indexrelid = to_regclass($1)", [@index])

    valid
  end
end
