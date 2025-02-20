defmodule Guard.FrontRepo.Migrations.AddTimestamptsToRepoHostAccount do
  use Ecto.Migration

  def change do
    alter table(:repo_host_accounts) do
      add :created_at, :utc_datetime
      add :updated_at, :utc_datetime
    end
  end
end
