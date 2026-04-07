defmodule Projecthub.Repo.Migrations.AddSemApproveEnableFlagsToProjects do
  use Ecto.Migration

  def change do
    alter table("projects") do
      add(:allow_sem_approve_include_secrets, :boolean, default: false, null: false)
      add(:allow_sem_approve_enable_cache, :boolean, default: false, null: false)
    end
  end
end
