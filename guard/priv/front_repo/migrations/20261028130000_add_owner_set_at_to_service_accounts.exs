defmodule Guard.FrontRepo.Migrations.AddOwnerSetAtToServiceAccounts do
  use Ecto.Migration

  def up do
    alter table(:service_accounts) do
      add :owner_set_at, :utc_datetime
    end

    execute("""
    UPDATE service_accounts SET owner_set_at = now() AT TIME ZONE 'utc'
     WHERE owner_id IS NOT NULL AND owner_set_at IS NULL
    """)
  end

  def down do
    alter table(:service_accounts) do
      remove :owner_set_at
    end
  end
end
