defmodule Guard.Repo.CliAuthCode do
  @moduledoc """
  Ecto schema for sem-ai CLI loopback-login authorization codes.
  Single-use, short-lived codes exchanged at POST /cli/token for the API token.
  Mirrors Guard.Repo.McpOAuthAuthCode.
  """

  use Guard.Repo.Schema
  alias Guard.Repo.RbacUser

  schema "cli_auth_codes" do
    field(:code, :string)
    field(:redirect_uri, :string)
    field(:code_challenge, :string)
    field(:expires_at, :utc_datetime)
    field(:used_at, :utc_datetime)

    belongs_to(:user, RbacUser, type: :binary_id, foreign_key: :user_id)

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(auth_code, attrs) do
    auth_code
    |> cast(attrs, [:code, :user_id, :redirect_uri, :code_challenge, :expires_at, :used_at])
    |> validate_required([:code, :user_id, :redirect_uri, :code_challenge, :expires_at])
    |> unique_constraint(:code)
    |> foreign_key_constraint(:user_id)
  end
end
