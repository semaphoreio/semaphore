defmodule Guard.FrontRepo.Migrations.AddOwnerToServiceAccounts do
  use Ecto.Migration

  def change do
    alter table(:service_accounts) do
      add :owner_id, :binary_id
    end
  end
end
