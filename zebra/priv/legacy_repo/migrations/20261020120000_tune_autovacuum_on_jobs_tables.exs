defmodule Zebra.LegacyRepo.Migrations.TuneAutovacuumOnJobsTables do
  use Ecto.Migration

  # Fixed dead-tuple thresholds instead of a scale factor, so vacuum frequency
  # does not drift as these tables grow.
  @thresholds [
    jobs: 500_000,
    job_stop_requests: 50_000
  ]

  def up do
    Enum.each(@thresholds, fn {table, threshold} ->
      execute(
        "ALTER TABLE #{table} SET (autovacuum_vacuum_scale_factor = 0, autovacuum_vacuum_threshold = #{threshold})"
      )
    end)
  end

  # Both tables had autovacuum_vacuum_scale_factor = 0.02 before this migration.
  def down do
    Enum.each(@thresholds, fn {table, _threshold} ->
      execute(
        "ALTER TABLE #{table} RESET (autovacuum_vacuum_scale_factor, autovacuum_vacuum_threshold)"
      )

      execute("ALTER TABLE #{table} SET (autovacuum_vacuum_scale_factor = 0.02)")
    end)
  end
end
