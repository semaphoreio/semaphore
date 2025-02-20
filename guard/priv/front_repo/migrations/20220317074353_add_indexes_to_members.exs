defmodule Guard.FrontRepo.Migrations.AddIndexesToMembers do
  use Ecto.Migration

  def change do
    create unique_index(:members, [:github_uid, :organization_id, :repo_host], name: :members_organization_repo_host_uid_index)
  end
end
