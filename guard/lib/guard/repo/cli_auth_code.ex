defmodule Guard.Repo.CliAuthCode do
  @moduledoc """
  Ecto schema for sem-ai CLI sign-in authorization records (RFC 8628 device
  grant, `flow_type = "device"`). Stores `device_code_hash` and
  `user_code_hash` (both sha256 hex), the requester context shown on the
  consent screen, and the poll `interval`.

  `status` moves `pending -> approved -> consumed` (or `pending -> denied`).
  Redemption is a SELECT FOR UPDATE transaction, so records are single-use and
  safe across guard's multiple pods.

  The `code`/`code_challenge`/`redirect_uri` columns (and the "loopback"
  flow_type) belonged to a since-removed RFC 8252 loopback + PKCE flow; they
  are kept in the schema so existing rows still load, but nothing writes them.
  """

  use Guard.Repo.Schema
  alias Guard.Repo.RbacUser

  @statuses ~w(pending approved denied consumed)
  @flow_types ~w(loopback device)
  @token_actions ~w(mint rotate)

  schema "cli_auth_codes" do
    field(:flow_type, :string)
    field(:status, :string, default: "pending")

    # legacy loopback columns (see moduledoc) — kept, never written
    field(:code, :string)
    field(:code_challenge, :string)
    field(:redirect_uri, :string)

    # device
    field(:device_code_hash, :string)
    field(:user_code_hash, :string)
    field(:requester_ip, :string)
    field(:requester_geo, :string)
    field(:requester_user_agent, :string)
    field(:interval, :integer, default: 5)
    field(:last_polled_at, :utc_datetime)
    field(:attempt_count, :integer, default: 0)

    # What the human consented to at approval: "mint" (fresh account) or
    # "rotate" (existing token, explicit reset consent). Null until approved.
    field(:token_action, :string)

    field(:expires_at, :utc_datetime)

    belongs_to(:user, RbacUser, type: :binary_id, foreign_key: :user_id)

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  @castable [
    :flow_type,
    :status,
    :code,
    :code_challenge,
    :redirect_uri,
    :device_code_hash,
    :user_code_hash,
    :requester_ip,
    :requester_geo,
    :requester_user_agent,
    :interval,
    :last_polled_at,
    :attempt_count,
    :token_action,
    :user_id,
    :expires_at
  ]

  def changeset(auth_code, attrs) do
    auth_code
    |> cast(attrs, @castable)
    |> validate_required([:flow_type, :status, :expires_at])
    |> validate_inclusion(:flow_type, @flow_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:token_action, @token_actions)
    |> unique_constraint(:code)
    |> unique_constraint(:device_code_hash)
    |> unique_constraint(:user_code_hash, name: :cli_auth_codes_pending_user_code_index)
    |> foreign_key_constraint(:user_id)
  end
end
