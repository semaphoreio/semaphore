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
  @spec find_by_code(String.t()) :: {:ok, McpOAuthAuthCode.t()} | {:error, :not_found | :expired | :used}
  def find_by_code(code) when is_binary(code) do
    query = from(ac in McpOAuthAuthCode, where: ac.code == ^code)

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      %McpOAuthAuthCode{used_at: used_at} when not is_nil(used_at) ->
        {:error, :used}

      %McpOAuthAuthCode{expires_at: expires_at} = auth_code ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :lt do
          {:error, :expired}
        else
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
  - grant_id (required)
  - expires_at (required)
  """
  @spec create(map()) :: {:ok, McpOAuthAuthCode.t()} | {:error, term()}
  def create(params) do
    changeset = McpOAuthAuthCode.changeset(%McpOAuthAuthCode{}, params)

    case Repo.insert(changeset) do
      {:ok, auth_code} -> {:ok, auth_code}
      {:error, changeset} -> {:error, changeset}
    end
  rescue
    e ->
      Logger.error("Error creating MCP OAuth auth code: #{inspect(e)}")
      {:error, :internal_error}
  end

  @doc """
  Mark an authorization code as used.
  This makes it single-use per OAuth spec.
  """
  @spec mark_used(McpOAuthAuthCode.t()) :: {:ok, McpOAuthAuthCode.t()} | {:error, term()}
  def mark_used(%McpOAuthAuthCode{} = auth_code) do
    changeset =
      auth_code
      |> Ecto.Changeset.change(%{used_at: DateTime.utc_now()})

    case Repo.update(changeset) do
      {:ok, updated} -> {:ok, updated}
      {:error, changeset} -> {:error, changeset}
    end
  rescue
    e ->
      Logger.error("Error marking auth code as used: #{inspect(e)}")
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
    from(ac in McpOAuthAuthCode,
      where: ac.expires_at < ^DateTime.utc_now()
    )
    |> Repo.delete_all()
  end
end
