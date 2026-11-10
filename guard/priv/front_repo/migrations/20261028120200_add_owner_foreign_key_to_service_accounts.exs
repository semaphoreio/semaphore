defmodule Guard.FrontRepo.Migrations.AddOwnerForeignKeyToServiceAccounts do
  use Ecto.Migration

  def up do
    alter table(:service_accounts) do
      modify :owner_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end
  end

  def down do
    drop constraint(:service_accounts, "service_accounts_owner_id_fkey")
  end
end
