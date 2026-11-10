defmodule Guard.FrontRepo.Migrations.AddOwnerIndexToServiceAccounts do
  use Ecto.Migration

  def change do
    create index(:service_accounts, [:owner_id], name: :index_service_accounts_on_owner_id)
  end
end
