class AddAgentProviderToJobs < ActiveRecord::Migration[6.1]
  # Plain SQL in a short transaction of its own: add_column deallocates cached prepared
  # statements first, which can abort a surrounding transaction.
  disable_ddl_transaction!

  # The agent provider that holds a hosted job's agent; empty means the default provider.
  # Where the column exists, jobs is not locked at all. Otherwise the ALTER gives up after
  # 5 s waiting for its exclusive lock instead of queueing every query on jobs behind it.
  def up
    return if column_exists?(:jobs, :agent_provider)

    transaction do
      execute "SET LOCAL lock_timeout = '5s'"
      execute "ALTER TABLE jobs ADD COLUMN IF NOT EXISTS agent_provider varchar(255)"
    end
  end

  def down
    return unless column_exists?(:jobs, :agent_provider)

    transaction do
      execute "SET LOCAL lock_timeout = '5s'"
      execute "ALTER TABLE jobs DROP COLUMN IF EXISTS agent_provider"
    end
  end
end
