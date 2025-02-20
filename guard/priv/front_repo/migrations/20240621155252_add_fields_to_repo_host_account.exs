defmodule Guard.FrontRepo.Migrations.AddFieldsToRepoHostAccount do
  use Ecto.Migration

  def change do
    alter table(:repo_host_accounts) do
      add :revoked, :boolean, default: false, null: false
      add :refresh_token, :string
    end
  end
end
