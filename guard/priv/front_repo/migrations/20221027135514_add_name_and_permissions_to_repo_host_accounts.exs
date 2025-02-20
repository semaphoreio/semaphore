defmodule Guard.FrontRepo.Migrations.AddNameAndPermissionsToRepoHostAccounts do
  use Ecto.Migration

  def change do
    alter table(:repo_host_accounts) do
      add :name, :string
      add :permission_scope, :string
    end
  end
end
