defmodule Guard.FrontRepo.Migrations.AddTokenExpiresAtToRepoHostAccounts do
  use Ecto.Migration

  def change do
    alter table(:repo_host_accounts) do
      add :token_expires_at, :utc_datetime
    end
  end
end
