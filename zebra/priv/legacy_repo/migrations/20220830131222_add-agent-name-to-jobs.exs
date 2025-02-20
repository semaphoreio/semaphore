defmodule :"Elixir.Zebra.LegacyRepo.Migrations.Add-agent-name-to-jobs" do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :agent_name, :string
    end
  end
end
