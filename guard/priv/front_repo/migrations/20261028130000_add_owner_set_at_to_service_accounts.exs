defmodule Guard.FrontRepo.Migrations.AddOwnerSetAtToServiceAccounts do
  use Ecto.Migration

  def up do
    # Give up rather than queue behind an open write and hold every later reader of the
    # table behind us.
    execute("SET LOCAL lock_timeout = '5s'")

    alter table(:service_accounts) do
      add :owner_set_at, :utc_datetime
    end

    execute("""
    UPDATE service_accounts SET owner_set_at = now() AT TIME ZONE 'utc' WHERE owner_id IS NOT NULL
    """)
  end

  def down do
    alter table(:service_accounts) do
      remove :owner_set_at
    end
  end
end
