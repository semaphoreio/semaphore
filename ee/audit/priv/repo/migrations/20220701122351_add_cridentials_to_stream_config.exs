defmodule Audit.Repo.Migrations.AddCridentialsToStreamConfig do
  use Ecto.Migration

  def change do
    alter table(:streamers) do
      add(:cridentials, :json)
    end
  end
end
