defmodule Guard.Store.McpOAuthRefreshToken do
  @moduledoc """
  Store module for MCP OAuth refresh tokens. A token is looked up by its SHA-256
  and rotates within the family started by one authorization code.
  """

  import Ecto.Query

  alias Guard.Repo
  alias Guard.Repo.{McpOAuthAuthCode, McpOAuthRefreshToken, McpOAuthRefreshTokenFamily}

  @revoked_retention_seconds 86_400

  @doc """
  Starts the family of refresh tokens an authorization code issues, and returns
  its first token.
  """
  @spec create(McpOAuthAuthCode.t(), String.t()) :: String.t()
  def create(%McpOAuthAuthCode{} = auth_code, scope) do
    now = now()

    family =
      Repo.insert!(%McpOAuthRefreshTokenFamily{
        auth_code_id: auth_code.id,
        client_id: auth_code.client_id,
        user_id: auth_code.user_id,
        scope: scope,
        resource: auth_code.resource,
        expires_at: DateTime.add(now, max_age_seconds())
      })

    insert_token(family, now)
  end

  @doc """
  Locks a token's family, then the token, using SELECT FOR UPDATE, and returns
  the token with its family. Must be called inside a Repo.transaction.
  """
  @spec lock_by_token(String.t()) :: {:ok, McpOAuthRefreshToken.t()} | {:error, :not_found}
  def lock_by_token(token) when is_binary(token) do
    # FOR UPDATE locks in FROM order. Locking the family first keeps rotate/1,
    # which writes the family's other tokens, from deadlocking.
    query =
      from(f in McpOAuthRefreshTokenFamily,
        join: t in McpOAuthRefreshToken,
        on: t.family_id == f.id,
        where: t.token_hash == ^hash(token),
        lock: "FOR UPDATE",
        select: {t, f}
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      {refresh_token, family} -> {:ok, %{refresh_token | family: family}}
    end
  end

  @doc """
  Marks every unused token of a locked token's family used, so that only the
  token it returns is live.
  """
  @spec rotate(McpOAuthRefreshToken.t()) :: String.t()
  def rotate(%McpOAuthRefreshToken{} = refresh_token) do
    now = now()

    McpOAuthRefreshToken
    |> where([t], t.family_id == ^refresh_token.family_id and is_nil(t.used_at))
    |> Repo.update_all(set: [used_at: now, updated_at: now])

    insert_token(refresh_token.family, now)
  end

  @doc """
  Revokes the live families issued from the client's authorization code, once
  used and not yet expired, and returns their users.
  """
  @spec revoke_issued_from_code(String.t(), String.t()) :: [Ecto.UUID.t()]
  def revoke_issued_from_code(code, client_id) do
    now = now()

    {_count, user_ids} =
      from(f in McpOAuthRefreshTokenFamily,
        join: c in McpOAuthAuthCode,
        on: c.id == f.auth_code_id,
        where: c.code == ^code and c.client_id == ^client_id,
        where: not is_nil(c.used_at) and c.expires_at > ^now and is_nil(f.revoked_at),
        select: f.user_id
      )
      |> Repo.update_all(set: [revoked_at: now, updated_at: now])

    user_ids
  end

  @spec revoke_family(McpOAuthRefreshTokenFamily.t()) :: McpOAuthRefreshTokenFamily.t()
  def revoke_family(%McpOAuthRefreshTokenFamily{} = family) do
    family |> Ecto.Changeset.change(revoked_at: now()) |> Repo.update!()
  end

  @doc """
  Deletes expired tokens, and expired families or ones revoked over a day ago
  along with their tokens. Returns the number of families and tokens deleted.
  """
  @spec cleanup_expired() :: {non_neg_integer(), non_neg_integer()}
  def cleanup_expired do
    now = now()
    revoked_before = DateTime.add(now, -@revoked_retention_seconds)

    {families, _} =
      McpOAuthRefreshTokenFamily
      |> where([f], f.expires_at < ^now or f.revoked_at < ^revoked_before)
      |> Repo.delete_all()

    {tokens, _} =
      McpOAuthRefreshToken
      |> where([t], t.expires_at < ^now)
      |> Repo.delete_all()

    {families, tokens}
  end

  defp insert_token(family, now) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    Repo.insert!(%McpOAuthRefreshToken{
      family_id: family.id,
      token_hash: hash(token),
      expires_at: Enum.min([DateTime.add(now, ttl_seconds()), family.expires_at], DateTime)
    })

    token
  end

  defp hash(token), do: :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp ttl_seconds, do: Application.fetch_env!(:guard, :mcp_oauth_refresh_token_ttl_seconds)

  defp max_age_seconds,
    do: Application.fetch_env!(:guard, :mcp_oauth_refresh_token_max_age_seconds)
end
