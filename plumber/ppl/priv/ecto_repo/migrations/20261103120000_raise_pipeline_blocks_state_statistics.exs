defmodule Ppl.EctoRepo.Migrations.RaisePipelineBlocksStateStatistics do
  use Ecto.Migration

  # Raises the planner statistics target of pipeline_blocks.state so the
  # planner estimates rare state values better on large tables.
  # SET STATISTICS does not block reads or writes; rollback restores the
  # default.
  def up do
    execute("ALTER TABLE pipeline_blocks ALTER COLUMN state SET STATISTICS 1000")
  end

  def down do
    execute("ALTER TABLE pipeline_blocks ALTER COLUMN state SET STATISTICS -1")
  end
end
