defmodule Guard.Repo.OIDCSession do
  use Guard.Repo.Schema

  schema "oidc_sessions" do
    belongs_to(:user, Guard.Repo.RbacUser)

    field(:id_token_enc, :binary)
    field(:refresh_token_enc, :binary)
    field(:expires_at, :utc_datetime_usec)

    field(:ip_address, :string, default: "")
    field(:user_agent, :string, default: "")

    timestamps(type: :utc_datetime_usec)
  end
end
