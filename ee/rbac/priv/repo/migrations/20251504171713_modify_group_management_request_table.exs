defmodule Rbac.Repo.Migrations.ModifyGroupManagementRequestTable do
  use Ecto.Migration

  def change do
    alter table(:group_management_request) do
      modify :user_id, :binary_id, null: true
      add :requester_id, :binary_id, null: true
    end
  end
end
