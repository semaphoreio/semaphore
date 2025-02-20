defmodule Guard.Repo.OIDCUser do
  use Guard.Repo.Schema

  schema "oidc_users" do
    belongs_to(:user, Guard.Repo.RbacUser)

    field(:oidc_user_id, :string)

    timestamps(type: :utc_datetime_usec)
  end
end
