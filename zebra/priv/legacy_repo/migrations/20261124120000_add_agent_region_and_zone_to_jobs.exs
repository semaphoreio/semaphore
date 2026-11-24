defmodule Zebra.LegacyRepo.Migrations.AddAgentRegionAndZoneToJobs do
  use Ecto.Migration

  # Nullable columns without a default only change the catalog, but the change
  # still takes a short exclusive lock on jobs: give up after 5 s instead of
  # queueing every query behind it, and run again.
  def up do
    execute("SET LOCAL lock_timeout = '5s'")

    alter table(:jobs) do
      add_if_not_exists(:agent_region, :string)
      add_if_not_exists(:agent_zone, :string)
    end
  end

  def down do
    execute("SET LOCAL lock_timeout = '5s'")

    alter table(:jobs) do
      remove_if_exists(:agent_region, :string)
      remove_if_exists(:agent_zone, :string)
    end
  end
end
