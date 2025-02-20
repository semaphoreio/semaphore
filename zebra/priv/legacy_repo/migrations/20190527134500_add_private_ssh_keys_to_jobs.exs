defmodule Zebra.LegacyRepo.Migrations.AddPrivateSshKeysToJobs do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :private_ssh_key, :text
    end
  end
end
