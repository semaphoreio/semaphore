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
end
