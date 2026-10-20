defmodule Ppl.EctoRepo.Migrations.TuneAutovacuumOnPipelineTables do
  use Ecto.Migration

  # Fixed dead-tuple thresholds instead of a scale factor, so vacuum frequency
  # does not drift as these tables grow.
  @thresholds [
    pipeline_blocks: 150_000,
    pipelines: 50_000,
    after_ppl_tasks: 20_000,
    pipeline_sub_inits: 20_000,
    time_limits: 20_000
  ]

  # Tables that had autovacuum_vacuum_scale_factor = 0.02 before this migration.
  @previous_scale_factor [:pipeline_blocks, :pipelines, :time_limits]

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
