defmodule Audit.Repo.Migrations.IntroduceEventTable do
  use Ecto.Migration

  def change do
    create table(:events) do
      add(:resource, :integer)
      add(:operation, :integer)

      add(:org_id, :binary_id)
      add(:user_id, :binary_id)
      add(:username, :string)
      add(:ip_address, :string)
      add(:operation_id, :string)

      add(:resource_id, :string)
      add(:resource_name, :string)
      add(:metadata, :json)

      add(:timestamp, :utc_datetime)
    end

    create(index(:events, [:org_id]))
  end
end
