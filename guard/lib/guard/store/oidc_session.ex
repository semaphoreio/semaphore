defmodule Guard.Store.OIDCSession do
  import Ecto.Query, only: [from: 2]

  @spec create(Map.t()) :: {:ok, Guard.Repo.OIDCSession.t()} | {:error, Ecto.Changeset.t()}
  def create(attributes) do
    %Guard.Repo.OIDCSession{}
    |> Ecto.Changeset.cast(
      attributes,
      [
        :user_id,
        :id_token_enc,
        :refresh_token_enc,
        :expires_at,
        :ip_address,
        :user_agent
      ]
    )
    |> Ecto.Changeset.validate_required([
      :user_id,
      :id_token_enc,
      :refresh_token_enc,
      :expires_at
    ])
    |> Guard.Repo.insert()
  end

  @spec update(Guard.Repo.OIDCSession.t(), String.t(), String.t(), DateTime.t()) ::
          {:ok, Guard.Repo.OIDCSession.t()} | {:error, Ecto.Changeset.t()}
  def update(session, id_token_enc, refresh_token_enc, expires_at) do
    session
    |> Ecto.Changeset.cast(
      %{id_token_enc: id_token_enc, refresh_token_enc: refresh_token_enc, expires_at: expires_at},
      [
        :id_token_enc,
        :refresh_token_enc,
        :expires_at
      ]
    )
    |> Ecto.Changeset.validate_required([:refresh_token_enc, :expires_at])
    |> Guard.Repo.update()
  end

  @spec expire(Guard.Repo.OIDCSession.t()) ::
          {:ok, Guard.Repo.OIDCSession.t()} | {:error, Ecto.Changeset.t()}
  def expire(session) do
    session
    |> Ecto.Changeset.cast(%{expires_at: DateTime.utc_now()}, [:expires_at])
    |> Ecto.Changeset.validate_required([:expires_at])
    |> Guard.Repo.update()
  end

  @spec delete(Guard.Repo.OIDCSession.t()) ::
          {:ok, Guard.Repo.OIDCSession} | {:error, Ecto.Changeset.t()}
  def delete(session) do
    Guard.Repo.delete(session)
  end

  @spec remove_refresh_token(Guard.Repo.OIDCSession.t()) ::
          {:ok, Guard.Repo.OIDCSession.t()} | {:error, Ecto.Changeset.t()}
  def remove_refresh_token(session) do
    session
    |> Ecto.Changeset.cast(%{refresh_token_enc: nil}, [:refresh_token_enc])
    |> Guard.Repo.update()
  end

  @spec get(Ecto.UUID.t()) :: {:ok, Guard.Repo.OIDCSession.t()} | {:error, :not_found}
  def get(id) do
    Guard.Repo.OIDCSession
    |> with_user()
    |> Guard.Repo.get(id)
    |> case do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  def with_user(query) do
    from(q in query, preload: [:user])
  end

  @spec expired?(Guard.Repo.OIDCSession.t()) :: boolean()
  def expired?(%Guard.Repo.OIDCSession{expires_at: nil}), do: true

  def expired?(%Guard.Repo.OIDCSession{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end

  @doc """
  Whether a session may be treated as an authenticated identity WITHOUT
  refreshing it: it must be unexpired and still hold its refresh token.

  A nil `refresh_token_enc` is how session revocation is recorded
  (`remove_refresh_token/1`), used for the strongest "signed out everywhere" /
  refresh-resolved-to-a-different-user paths that null the refresh token without
  moving `expires_at`. Callers that consume a session as identity but do NOT
  perform the OIDC refresh (e.g. the MCP OAuth authorize flow) MUST gate on this
  so a revoked-but-not-yet-expired session cannot be used.

  This mirrors the accept-path rejections in
  `Guard.GrpcServers.AuthServer.process_session/3` for a non-expired session
  (session missing / `refresh_token_enc: nil`); keep the two in sync.
  """
  @spec valid_for_auth?(Guard.Repo.OIDCSession.t()) :: boolean()
  def valid_for_auth?(%Guard.Repo.OIDCSession{refresh_token_enc: nil}), do: false

  def valid_for_auth?(%Guard.Repo.OIDCSession{} = session) do
    not expired?(session)
  end
end
