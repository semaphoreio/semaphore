defmodule Rbac.Repo.Migrations.CreateCollabotorRefreshRequestTable do
  use Ecto.Migration

  def change do
    create table(:collaborator_refresh_requests, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:org_id, :binary_id, null: false)
      add(:state, :string, null: false)
      add(:requester_user_id, :binary_id, null: true)
      add(:remaining_project_ids, {:array, :binary_id})

      timestamps()
    end

    create(index("collaborator_refresh_requests", [:org_id, :state]))
  end
end
