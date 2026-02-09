defmodule Guard.Store.McpOAuthAuthCode do
  @moduledoc """
  Store module for MCP OAuth authorization code operations.
  Manages single-use, short-lived authorization codes for the OAuth flow.
  """

  require Logger
  import Ecto.Query

  alias Guard.Repo
  alias Guard.Repo.McpOAuthAuthCode

  @doc """
  Atomically find and consume an authorization code.
  Uses UPDATE ... WHERE used_at IS NULL to prevent TOCTOU race conditions.
  Only one concurrent request can successfully consume a given code.
  """
  @spec consume_code(String.t(), String.t()) ::
          {:ok, McpOAuthAuthCode.t()} | {:error, :invalid_or_used}
  def consume_code(code, client_id) when is_binary(code) and is_binary(client_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    query =
      from(ac in McpOAuthAuthCode,
        where:
          ac.code == ^code and is_nil(ac.used_at) and ac.expires_at > ^now and
            ac.client_id == ^client_id,
        select: ac
      )

    case Repo.update_all(query, set: [used_at: now]) do
      {1, [auth_code]} -> {:ok, auth_code}
      {0, _} -> {:error, :invalid_or_used}
    end
  end

  @doc """
  Create a new authorization code.

  Expects params map with:
  - code (required)
  - client_id (required)
  - user_id (required)
  - redirect_uri (required)
  - code_challenge (required, for PKCE)
  - expires_at (required)
  """
  @spec create(map()) :: {:ok, McpOAuthAuthCode.t()} | {:error, term()}
  def create(params) do
    Logger.debug(
      "[McpOAuthAuthCode] Creating auth code for client=#{params[:client_id]}, user=#{params[:user_id]}"
    )

    changeset = McpOAuthAuthCode.changeset(%McpOAuthAuthCode{}, params)

    case Repo.insert(changeset) do
      {:ok, auth_code} ->
        Logger.debug(
          "[McpOAuthAuthCode] Created auth code: id=#{auth_code.id}, code=#{String.slice(auth_code.code, 0, 8)}..."
        )

        {:ok, auth_code}

      {:error, changeset} ->
        Logger.error(
          "[McpOAuthAuthCode] Failed to create auth code: #{inspect(changeset.errors)}"
        )

        {:error, changeset}
    end
  rescue
    e ->
      Logger.error("[McpOAuthAuthCode] Exception creating MCP OAuth auth code: #{inspect(e)}")

      Logger.error(
        "[McpOAuthAuthCode] Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}"
      )

      {:error, :internal_error}
  end

  @doc """
  Generate a new authorization code string.
  Uses secure random bytes encoded as URL-safe base64.
  """
  @spec generate_code() :: String.t()
  def generate_code do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Clean up expired authorization codes.
  Should be called periodically to prevent table bloat.
  """
  @spec cleanup_expired() :: {integer(), nil}
  def cleanup_expired do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(ac in McpOAuthAuthCode,
      where: ac.expires_at < ^now
    )
    |> Repo.delete_all()
  end
end
