defmodule Guard.FrontRepo.Migrations.AddOwnerToServiceAccounts do
  use Ecto.Migration

  def change do
    # The foreign key takes a lock on users as well, so give up rather than queue behind
    # an open write and hold every reader of both tables behind us.
    execute("SET LOCAL lock_timeout = '5s'", "")

    alter table(:service_accounts) do
      add :owner_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:service_accounts, [:owner_id])
  end
end
