class AddAgentRegionAndZoneToJobs < ActiveRecord::Migration[8.1]
  # Plain SQL in a short transaction of its own: add_column deallocates cached prepared
  # statements first, which can abort a surrounding transaction.
  disable_ddl_transaction!

  # Where a hosted job's agent runs, as its provider reports it; empty when it does not.
  # Where the columns exist, jobs is not locked at all. Otherwise the ALTER gives up after
  # 5 s waiting for its exclusive lock instead of queueing every query on jobs behind it.
  def up
    return if column_exists?(:jobs, :agent_region) && column_exists?(:jobs, :agent_zone)

    transaction do
      execute "SET LOCAL lock_timeout = '5s'"
      execute "ALTER TABLE jobs ADD COLUMN IF NOT EXISTS agent_region varchar(255), " \
              "ADD COLUMN IF NOT EXISTS agent_zone varchar(255)"
    end
  end

  def down
    return unless column_exists?(:jobs, :agent_region) || column_exists?(:jobs, :agent_zone)

    transaction do
      execute "SET LOCAL lock_timeout = '5s'"
      execute "ALTER TABLE jobs DROP COLUMN IF EXISTS agent_region, " \
              "DROP COLUMN IF EXISTS agent_zone"
    end
  end
end
