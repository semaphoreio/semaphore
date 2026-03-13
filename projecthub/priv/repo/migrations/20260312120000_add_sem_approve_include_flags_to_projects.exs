defmodule Projecthub.Repo.Migrations.AddSemApproveIncludeFlagsToProjects do
  use Ecto.Migration

  def change do
    alter table("projects") do
      add(:allow_sem_approve_include_secrets, :boolean, default: false, null: false)
      add(:allow_sem_approve_include_cache, :boolean, default: false, null: false)
    end
  end
end
