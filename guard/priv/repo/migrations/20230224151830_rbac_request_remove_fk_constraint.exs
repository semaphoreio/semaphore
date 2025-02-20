defmodule Guard.Repo.Migrations.RbacRequestRemoveFkConstraint do
  use Ecto.Migration

  def change do
    drop constraint(:rbac_refresh_permissions_requests, :rbac_refresh_permissions_requests_user_id_fkey)
  end
end
