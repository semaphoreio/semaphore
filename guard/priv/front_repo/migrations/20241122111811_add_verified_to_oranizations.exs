defmodule Guard.FrontRepo.Migrations.AddVerifiedToOranizations do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add(:verified, :boolean)
      add(:ip_allow_list, :string, null: false, default: "")
      add(:allowed_id_providers, :string, null: false, default: "")
      add(:deny_member_workflows, :boolean, null: false, default: false)
      add(:deny_non_member_workflows, :boolean, null: false, default: false)
    end
  end
end
