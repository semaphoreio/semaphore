defmodule Guard.Repo.McpOAuthConsentChallenge do
  @moduledoc """
  Ecto schema for one-time MCP OAuth consent challenges.
  """

  use Guard.Repo.Schema

  alias Guard.Repo.RbacUser

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "mcp_oauth_consent_challenges" do
    field(:client_id, :string)
    field(:client_name, :string)
    field(:redirect_uri, :string)
    field(:code_challenge, :string)
    field(:code_challenge_method, :string)
    field(:state, :string)
    field(:requested_scope, :string)
    field(:expires_at, :utc_datetime)
    field(:consumed_at, :utc_datetime)

    belongs_to(:user, RbacUser, type: :binary_id, foreign_key: :user_id)

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(challenge, attrs) do
    challenge
    |> cast(attrs, [
      :user_id,
      :client_id,
      :client_name,
      :redirect_uri,
      :code_challenge,
      :code_challenge_method,
      :state,
      :requested_scope,
      :expires_at,
      :consumed_at
    ])
    |> validate_required([
      :user_id,
      :client_id,
      :redirect_uri,
      :code_challenge,
      :code_challenge_method,
      :expires_at
    ])
    |> foreign_key_constraint(:user_id)
  end
end
