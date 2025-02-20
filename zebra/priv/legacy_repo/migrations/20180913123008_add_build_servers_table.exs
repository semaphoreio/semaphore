defmodule Zebra.Repo.Migrations.AddBuildServersTable do
  use Ecto.Migration

  def change do
    create table(:build_servers) do
      add :name, :string
      add :ip_address, :string
      add :core_count, :integer
      add :enabled, :boolean
      add :metadata, :text
      add :created_at, :utc_datetime
      add :updated_at, :utc_datetime
    end
  end
end
