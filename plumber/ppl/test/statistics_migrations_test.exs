defmodule Ppl.StatisticsMigrationsTest do
  @moduledoc """
  The 20261103120000 migration raises the statistics target of
  pipeline_blocks.state, and its rollback restores the default.
  """
  use ExUnit.Case

  alias Ppl.EctoRepo, as: Repo
  alias Ppl.EctoRepo.Migrations.RaisePipelineBlocksStateStatistics, as: Migration

  # Not a real migration version: used to run the migration without touching
  # the recorded history.
  @rerun_version 99_990_103_000_000

  @migration_file "priv/ecto_repo/migrations/20261103120000_raise_pipeline_blocks_state_statistics.exs"

  setup_all do
    # Migrations live in priv and are not compiled with the app.
    unless Code.ensure_loaded?(Migration), do: Code.require_file(@migration_file)
    :ok
  end

  setup do
    on_exit(fn ->
      Repo.query!("ALTER TABLE pipeline_blocks ALTER COLUMN state SET STATISTICS 1000")
      Repo.query!("DELETE FROM schema_migrations WHERE version = $1", [@rerun_version])
    end)
  end

  test "the migrated schema has the raised target" do
    assert statistics_target() == 1000
  end

  test "rollback resets the target to the default and up raises it again" do
    assert :ok == Ecto.Migrator.up(Repo, @rerun_version, Migration, log: false)
    assert statistics_target() == 1000

    assert :ok == Ecto.Migrator.down(Repo, @rerun_version, Migration, log: false)
    assert statistics_target() == -1

    assert :ok == Ecto.Migrator.up(Repo, @rerun_version, Migration, log: false)
    assert statistics_target() == 1000
  end

  test "the other pipeline_blocks columns keep the default target" do
    %{rows: rows} =
      Repo.query!("""
      SELECT attname FROM pg_attribute
      WHERE attrelid = 'pipeline_blocks'::regclass AND attnum > 0 AND NOT attisdropped
        AND attname <> 'state' AND COALESCE(attstattarget, -1) <> -1
      """)

    assert rows == []
  end

  # PG 17+ stores the default as NULL, older versions as -1.
  defp statistics_target do
    %{rows: [[target]]} =
      Repo.query!("""
      SELECT COALESCE(attstattarget, -1) FROM pg_attribute
      WHERE attrelid = 'pipeline_blocks'::regclass AND attname = 'state'
      """)

    target
  end
end
