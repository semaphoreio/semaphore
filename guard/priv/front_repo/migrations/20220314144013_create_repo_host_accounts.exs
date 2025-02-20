defmodule Guard.FrontRepo.Migrations.CreateRepoHostAccounts do
  use Ecto.Migration

  def change do
    create table(:repo_host_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :login, :string
      add :github_uid, :string
      add :repo_host, :string
      add :token, :string
      add :user_id, :binary_id
    end
  end
end
