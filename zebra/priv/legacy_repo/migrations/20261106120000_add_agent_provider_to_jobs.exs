defmodule Zebra.LegacyRepo.Migrations.AddAgentProviderToJobs do
  use Ecto.Migration

  # A nullable column without a default only changes the catalog, but the change
  # still takes a short exclusive lock on jobs: give up after 5 s instead of
  # queueing every query behind it, and run again.
  def up do
    execute("SET LOCAL lock_timeout = '5s'")

    alter table(:jobs) do
      add_if_not_exists(:agent_provider, :string)
    end
  end

  def down do
    execute("SET LOCAL lock_timeout = '5s'")

    alter table(:jobs) do
      remove_if_exists(:agent_provider, :string)
    end
  end
end
