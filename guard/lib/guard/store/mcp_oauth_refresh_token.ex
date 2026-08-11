defmodule Guard.Store.McpOAuthRefreshToken do
  @moduledoc """
  Store module for MCP OAuth refresh token operations.

  Refresh tokens let MCP clients renew a short-lived access token without a new
  browser round trip. MCP clients are public clients (PKCE, no client secret),
  so the OAuth 2.1 rules for them apply: tokens are single-use, every refresh
  rotates them, and replay of an already-used token revokes the whole token
  family (`revoke_family/1`).

  Rotation is multi-pod safe: `lock_token/2` takes the row with SELECT FOR
  UPDATE inside a transaction and the caller marks it used in the same
  transaction, so two concurrent refreshes with the same token serialize and
  exactly one of them wins. Only the sha256 hash of a token is stored; the
  plaintext is returned once, at issue time.
  """

  require Logger
  import Ecto.Query

  alias Guard.Repo
  alias Guard.Repo.McpOAuthRefreshToken

  @doc """
  Generate a new refresh token string.
  Uses secure random bytes encoded as URL-safe base64.
  """
  @spec generate_token() :: String.t()
  def generate_token do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  @doc "sha256 hex hash used for refresh tokens at rest."
  @spec hash(String.t()) :: String.t()
  def hash(value) when is_binary(value),
    do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  @doc """
  Returns the configured refresh token TTL in seconds.
  """
  @spec ttl_seconds() :: pos_integer()
  def ttl_seconds do
    Application.fetch_env!(:guard, :mcp_oauth_refresh_token_ttl_seconds)
  end

  @doc """
  Issue a new refresh token and return its plaintext alongside the stored row.

  Expects params map with:
  - client_id (required)
  - user_id (required)
  - family_id (optional): reuse the family of the token being rotated. A new
    family is started when omitted (i.e. on authorization code exchange).
  - expires_at (optional): defaults to now + `ttl_seconds/0`
  """
  @spec issue(map()) :: {:ok, String.t(), McpOAuthRefreshToken.t()} | {:error, term()}
  def issue(params) do
    token = generate_token()

    attrs = %{
      token_hash: hash(token),
      family_id: params[:family_id] || Ecto.UUID.generate(),
      client_id: params[:client_id],
      user_id: params[:user_id],
      expires_at: params[:expires_at] || default_expires_at()
    }

    changeset = McpOAuthRefreshToken.changeset(%McpOAuthRefreshToken{}, attrs)

    case Repo.insert(changeset) do
      {:ok, refresh_token} ->
        Logger.debug(
          "[McpOAuthRefreshToken] Issued refresh token: id=#{refresh_token.id}, family=#{refresh_token.family_id}"
        )

        {:ok, token, refresh_token}

      {:error, changeset} ->
        Logger.error(
          "[McpOAuthRefreshToken] Failed to issue refresh token: #{inspect(changeset.errors)}"
        )

        {:error, changeset}
    end
  end

  @doc """
  Lock a refresh token row by plaintext token and client_id using SELECT FOR
  UPDATE. Must be called inside a Repo.transaction.

  The row is returned regardless of its used/revoked/expired state so that the
  caller can tell replay apart from an unknown token.
  """
  @spec lock_token(String.t(), String.t()) ::
          {:ok, McpOAuthRefreshToken.t()} | {:error, :not_found}
  def lock_token(token, client_id) when is_binary(token) and is_binary(client_id) do
    token_hash = hash(token)

    query =
      McpOAuthRefreshToken
      |> where([rt], rt.token_hash == ^token_hash and rt.client_id == ^client_id)
      |> lock("FOR UPDATE")

    case Repo.one(query) do
      nil -> {:error, :not_found}
      refresh_token -> {:ok, refresh_token}
    end
  end

  @doc """
  Mark a previously locked refresh token as used.
  Must be called inside the same transaction as `lock_token/2`.
  """
  @spec mark_used(McpOAuthRefreshToken.t()) :: {:ok, McpOAuthRefreshToken.t()} | {:error, term()}
  def mark_used(%McpOAuthRefreshToken{} = refresh_token) do
    refresh_token
    |> Ecto.Changeset.change(used_at: now())
    |> Repo.update()
  end

  @doc """
  Revoke every still-active token in a family. Used on replay detection: a
  leaked token and the tokens rotated from it are all invalidated at once.
  Returns the number of tokens revoked.
  """
  @spec revoke_family(binary()) :: {integer(), nil}
  def revoke_family(family_id) do
    McpOAuthRefreshToken
    |> where([rt], rt.family_id == ^family_id and is_nil(rt.revoked_at))
    |> Repo.update_all(set: [revoked_at: now(), updated_at: now()])
  end

  @doc """
  Clean up expired refresh tokens.
  Should be called periodically to prevent table bloat.

  Only expired rows are removed: used rows are kept until they expire so replay
  of a rotated token is still detected.
  """
  @spec cleanup_expired() :: {integer(), nil}
  def cleanup_expired do
    McpOAuthRefreshToken
    |> where([rt], rt.expires_at < ^now())
    |> Repo.delete_all()
  end

  defp default_expires_at do
    now() |> DateTime.add(ttl_seconds(), :second)
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
