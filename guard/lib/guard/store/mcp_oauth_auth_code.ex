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
  Lock a valid, unused authorization code within a transaction using SELECT FOR UPDATE.
  Must be called inside a Repo.transaction. Returns the auth code without marking it as used.
  """
  @spec lock_code(String.t(), String.t()) ::
          {:ok, McpOAuthAuthCode.t()} | {:error, :invalid_or_used}
  def lock_code(code, client_id) when is_binary(code) and is_binary(client_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    query =
      McpOAuthAuthCode
      |> where([ac], ac.code == ^code and ac.client_id == ^client_id)
      |> where([ac], is_nil(ac.used_at) and ac.expires_at > ^now)
      |> lock("FOR UPDATE")

    case Repo.one(query) do
      nil -> {:error, :invalid_or_used}
      auth_code -> {:ok, auth_code}
    end
  end

  @doc """
  Mark a previously locked authorization code as used.
  Must be called inside the same transaction as lock_code/2.
  """
  @spec mark_code_used(McpOAuthAuthCode.t()) :: {:ok, McpOAuthAuthCode.t()}
  def mark_code_used(%McpOAuthAuthCode{} = auth_code) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    auth_code
    |> Ecto.Changeset.change(used_at: now)
    |> Repo.update()
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

    McpOAuthAuthCode
    |> where([ac], ac.expires_at < ^now)
    |> Repo.delete_all()
  end
end
