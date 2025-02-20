defmodule Guard.Repo.Migrations.RenameRbacResreshRequestsTable do
  use Ecto.Migration

  def change do
    rename table("rbac_refresh_permissions_requests"), to: table("rbac_refresh_project_access_requests")
  end
end
