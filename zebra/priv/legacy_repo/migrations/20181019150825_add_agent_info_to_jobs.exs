defmodule Zebra.Repo.Migrations.AddAgentInfoToJobs do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :agent_id, :binary_id
      add :agent_ip_address, :string
      add :agent_ctrl_port, :integer
    end
  end
end
