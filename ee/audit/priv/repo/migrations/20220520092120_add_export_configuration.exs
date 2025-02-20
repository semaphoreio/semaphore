defmodule Audit.Repo.Migrations.AddExportConfiguration do
  use Ecto.Migration

  def change do
    create table(:streamers, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:org_id, :binary_id)
      add(:provider, :integer)

      add(:status, :integer)
      add(:last_streamed, :utc_datetime)
      add(:metadata, :json)
    end

    alter table(:events) do
      add(:streamed, :boolean, default: false)
    end

  end
end
