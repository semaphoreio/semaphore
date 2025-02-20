defmodule Guard.Repo.Migrations.CreateRbacRefreshAllPermissionsRequests do
  use Ecto.Migration

  def change do
    create table(:rbac_refresh_all_permissions_requests) do
      add :state, :string, default: "pending"
      add :organizations_updated, :integer, default: 0
      add :retries, :integer, default: 0

      timestamps()
    end
  end
end
