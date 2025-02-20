defmodule Guard.FrontRepo.Migrations.AddSettingsToOrganizations do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add(:settings, :map)
    end
  end
end
