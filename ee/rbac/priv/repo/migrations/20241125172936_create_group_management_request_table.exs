defmodule Rbac.Repo.Migrations.CreateGroupManagementRequestTable do
  use Ecto.Migration

  def change do
    create table(:group_management_request) do
      add :state, :string, default: "pending"
      add :user_id, :binary_id, null: false
      add :group_id, :binary_id, null: false
      add :action, :string, null: false
      add :retries, :integer, default: 0

      timestamps()
    end
  end
end
