defmodule Zebra.LegacyRepo.Migrations.TuneAutovacuumOnJobsTables do
  use Ecto.Migration

  # Fixed dead-tuple thresholds instead of a scale factor, so vacuum frequency
  # does not drift as these tables grow.
  @thresholds [
    jobs: 500_000,
    job_stop_requests: 50_000,
    builds: 200_000
  ]

  # Tables that had autovacuum_vacuum_scale_factor = 0.02 before this migration.
  @previous_scale_factor [:jobs, :job_stop_requests]

  def up do
    Enum.each(@thresholds, fn {table, threshold} ->
      execute(
        "ALTER TABLE #{table} SET (autovacuum_vacuum_scale_factor = 0, autovacuum_vacuum_threshold = #{threshold})"
      )
    end)
  end

  def down do
    Enum.each(@thresholds, fn {table, _threshold} ->
      execute(
        "ALTER TABLE #{table} RESET (autovacuum_vacuum_scale_factor, autovacuum_vacuum_threshold)"
      )

      if table in @previous_scale_factor do
        execute("ALTER TABLE #{table} SET (autovacuum_vacuum_scale_factor = 0.02)")
      end
    end)
  end
end
