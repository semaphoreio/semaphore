defmodule Zebra.LegacyRepo.Migrations.AddAuthTokenToJobsTable do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :agent_auth_token, :string
    end
  end
end
