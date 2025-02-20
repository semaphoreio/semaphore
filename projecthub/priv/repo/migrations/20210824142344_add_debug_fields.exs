defmodule Projecthub.Repo.Migrations.AddDebugFields do
  use Ecto.Migration

  def change do
		alter table("projects") do
			add :debug_empty, :boolean, default: false, null: false
			add :debug_default_branch, :boolean, default: false, null: false
			add :debug_non_default_branch, :boolean, default: false, null: false
			add :debug_pr, :boolean, default: false, null: false
			add :debug_forked_pr, :boolean, default: false, null: false
			add :debug_tag, :boolean, default: false, null: false

			add :attach_empty, :boolean, default: false, null: false
			add :attach_default_branch, :boolean, default: false, null: false
			add :attach_non_default_branch, :boolean, default: false, null: false
			add :attach_pr, :boolean, default: false, null: false
			add :attach_forked_pr, :boolean, default: false, null: false
			add :attach_tag, :boolean, default: false, null: false
		end
  end
end
