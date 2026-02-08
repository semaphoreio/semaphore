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
  Find an authorization code by its code value.
  Only returns unused, non-expired codes.
  """
  @spec find_by_code(String.t()) ::
          {:ok, McpOAuthAuthCode.t()} | {:error, :not_found | :expired | :used}
  def find_by_code(code) when is_binary(code) do
    Logger.debug("[McpOAuthAuthCode] Looking up code: #{String.slice(code, 0, 8)}...")
    query = from(ac in McpOAuthAuthCode, where: ac.code == ^code)

    case Repo.one(query) do
      nil ->
        Logger.warning("[McpOAuthAuthCode] Code not found")
        {:error, :not_found}

      %McpOAuthAuthCode{used_at: used_at} = auth_code when not is_nil(used_at) ->
        Logger.warning("[McpOAuthAuthCode] Code already used: id=#{auth_code.id}")
        {:error, :used}

      %McpOAuthAuthCode{expires_at: expires_at} = auth_code ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :lt do
          Logger.warning("[McpOAuthAuthCode] Code expired: id=#{auth_code.id}")
          {:error, :expired}
        else
          Logger.debug("[McpOAuthAuthCode] Found valid code: id=#{auth_code.id}, client=#{auth_code.client_id}")
          {:ok, auth_code}
        end
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
    Logger.debug("[McpOAuthAuthCode] Creating auth code for client=#{params[:client_id]}, user=#{params[:user_id]}")

    changeset = McpOAuthAuthCode.changeset(%McpOAuthAuthCode{}, params)

    case Repo.insert(changeset) do
      {:ok, auth_code} ->
        Logger.debug("[McpOAuthAuthCode] Created auth code: id=#{auth_code.id}, code=#{String.slice(auth_code.code, 0, 8)}...")
        {:ok, auth_code}

      {:error, changeset} ->
        Logger.error("[McpOAuthAuthCode] Failed to create auth code: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  rescue
    e ->
      Logger.error("[McpOAuthAuthCode] Exception creating MCP OAuth auth code: #{inspect(e)}")
      Logger.error("[McpOAuthAuthCode] Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")
      {:error, :internal_error}
  end

  @doc """
  Mark an authorization code as used.
  This makes it single-use per OAuth spec.
  """
  @spec mark_used(McpOAuthAuthCode.t()) :: {:ok, McpOAuthAuthCode.t()} | {:error, term()}
  def mark_used(%McpOAuthAuthCode{} = auth_code) do
    Logger.debug("[McpOAuthAuthCode] Marking code as used: id=#{auth_code.id}")

    changeset =
      auth_code
      |> Ecto.Changeset.change(%{used_at: DateTime.utc_now() |> DateTime.truncate(:second)})

    case Repo.update(changeset) do
      {:ok, updated} ->
        Logger.debug("[McpOAuthAuthCode] Successfully marked code as used: id=#{updated.id}")
        {:ok, updated}

      {:error, changeset} ->
        Logger.error(
          "[McpOAuthAuthCode] Failed to mark code as used: #{inspect(changeset.errors)}"
        )

        {:error, changeset}
    end
  rescue
    e ->
      Logger.error("[McpOAuthAuthCode] Exception marking auth code as used: #{inspect(e)}")
      Logger.error("[McpOAuthAuthCode] Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")
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
