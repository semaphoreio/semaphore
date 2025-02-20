defmodule Rbac.Repo.OIDCUser do
  use Rbac.Repo.Schema

  schema "oidc_users" do
    belongs_to(:user, Rbac.Repo.RbacUser)

    field(:oidc_user_id, :string)

    timestamps(type: :utc_datetime_usec)
  end
end
