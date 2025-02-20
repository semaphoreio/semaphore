defmodule Secrethub.Repo.Migrations.ChangeUsageToJson do
  use Ecto.Migration

  def change do
    alter table(:secrets) do
      remove(:used_by)
    end
    alter table(:secrets) do
      add(:used_by, :json)
    end
  end
end
