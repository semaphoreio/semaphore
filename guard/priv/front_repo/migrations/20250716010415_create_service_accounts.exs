defmodule Guard.FrontRepo.Migrations.CreateServiceAccounts do
  use Ecto.Migration

  def change do
    create table(:service_accounts, primary_key: false) do
      add :id, references(:users, type: :binary_id, on_delete: :delete_all),
          primary_key: true, null: false
      add :description, :string, size: 500
      add :creator_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
