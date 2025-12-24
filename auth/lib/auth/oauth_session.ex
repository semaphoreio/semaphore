defmodule Auth.OAuthSession do
  @moduledoc """
  Manages OAuth flow state in Cachex for MCP grant correlation.

  Stores session data during the OAuth authorization flow to correlate:
  - Client authorization requests
  - Grant selection in Guard
  - Keycloak callbacks
  - Token exchange requests

  Sessions are stored with a 5-minute TTL to prevent stale data.
  """

  require Logger

  @cache_name :oauth_sessions
  @ttl :timer.minutes(5)

  @doc """
  Creates a new OAuth session.

  ## Parameters
  - correlation_id: Unique identifier for this OAuth flow
  - session_data: Map containing client_id, client_state, redirect_uri, scope, etc.

  ## Examples

      iex> Auth.OAuthSession.create("uuid", %{client_id: "test", scope: "mcp"})
      {:ok, "uuid"}
  """
  def create(correlation_id, session_data) when is_binary(correlation_id) and is_map(session_data) do
    enriched_data =
      session_data
      |> Map.put(:correlation_id, correlation_id)
      |> Map.put(:created_at, DateTime.utc_now())

    case Cachex.put(@cache_name, correlation_id, enriched_data, ttl: @ttl) do
      {:ok, true} ->
        Logger.debug("[OAuthSession] Created session #{correlation_id}")
        {:ok, correlation_id}

      {:error, reason} ->
        Logger.error("[OAuthSession] Failed to create session: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Retrieves an OAuth session by correlation ID.

  ## Examples

      iex> Auth.OAuthSession.get("uuid")
      {:ok, %{client_id: "test", correlation_id: "uuid", ...}}
  """
  def get(correlation_id) when is_binary(correlation_id) do
    case Cachex.get(@cache_name, correlation_id) do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, session_data} ->
        {:ok, session_data}

      {:error, reason} ->
        Logger.error("[OAuthSession] Failed to get session #{correlation_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Updates an OAuth session with new data.

  Merges the updates into the existing session data.

  ## Examples

      iex> Auth.OAuthSession.update("uuid", %{grant_id: "grant-uuid"})
      {:ok, %{client_id: "test", grant_id: "grant-uuid", ...}}
  """
  def update(correlation_id, updates) when is_binary(correlation_id) and is_map(updates) do
    case get(correlation_id) do
      {:ok, session} ->
        updated_session = Map.merge(session, updates)

        case Cachex.put(@cache_name, correlation_id, updated_session, ttl: @ttl) do
          {:ok, true} ->
            Logger.debug("[OAuthSession] Updated session #{correlation_id}")
            {:ok, updated_session}

          {:error, reason} ->
            Logger.error("[OAuthSession] Failed to update session: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, :not_found} ->
        Logger.warn("[OAuthSession] Cannot update non-existent session #{correlation_id}")
        {:error, :not_found}

      error ->
        error
    end
  end

  @doc """
  Stores grant information in the OAuth session.

  This is called by Guard after creating the MCP grant.

  ## Examples

      iex> Auth.OAuthSession.store_grant("uuid", "grant-uuid", ["mcp:workflows:run"])
      {:ok, %{...}}
  """
  def store_grant(correlation_id, grant_id, tool_scopes)
      when is_binary(correlation_id) and is_binary(grant_id) and is_list(tool_scopes) do
    update(correlation_id, %{grant_id: grant_id, tool_scopes: tool_scopes})
  end

  @doc """
  Stores the authorization code in the OAuth session.

  Creates a reverse lookup so we can find the session by auth_code during token exchange.

  ## Examples

      iex> Auth.OAuthSession.store_auth_code("uuid", "auth-code-123")
      {:ok, %{...}}
  """
  def store_auth_code(correlation_id, auth_code)
      when is_binary(correlation_id) and is_binary(auth_code) do
    with {:ok, session} <- update(correlation_id, %{auth_code: auth_code}) do
      # Create reverse lookup: auth_code -> correlation_id
      code_key = auth_code_key(auth_code)

      case Cachex.put(@cache_name, code_key, correlation_id, ttl: @ttl) do
        {:ok, true} ->
          Logger.debug("[OAuthSession] Stored auth code for session #{correlation_id}")
          {:ok, session}

        {:error, reason} ->
          Logger.error("[OAuthSession] Failed to store auth code lookup: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @doc """
  Retrieves an OAuth session by authorization code.

  Used during token exchange to look up the grant_id.

  ## Examples

      iex> Auth.OAuthSession.get_by_auth_code("auth-code-123")
      {:ok, %{grant_id: "grant-uuid", ...}}
  """
  def get_by_auth_code(auth_code) when is_binary(auth_code) do
    code_key = auth_code_key(auth_code)

    with {:ok, correlation_id} when not is_nil(correlation_id) <- Cachex.get(@cache_name, code_key),
         {:ok, session} <- get(correlation_id) do
      {:ok, session}
    else
      {:ok, nil} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes an OAuth session.

  Should be called after successful token exchange to cleanup.

  ## Examples

      iex> Auth.OAuthSession.delete("uuid")
      :ok
  """
  def delete(correlation_id) when is_binary(correlation_id) do
    # Get session first to cleanup auth code reverse lookup
    case get(correlation_id) do
      {:ok, %{auth_code: auth_code}} when not is_nil(auth_code) ->
        code_key = auth_code_key(auth_code)
        Cachex.del(@cache_name, code_key)
        Cachex.del(@cache_name, correlation_id)
        Logger.debug("[OAuthSession] Deleted session #{correlation_id} and auth code lookup")
        :ok

      {:ok, _session} ->
        Cachex.del(@cache_name, correlation_id)
        Logger.debug("[OAuthSession] Deleted session #{correlation_id}")
        :ok

      {:error, :not_found} ->
        Logger.debug("[OAuthSession] Session #{correlation_id} already deleted or never existed")
        :ok

      {:error, reason} ->
        Logger.error("[OAuthSession] Failed to delete session #{correlation_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Deletes an OAuth session by authorization code.

  Convenience function for cleanup after token exchange.
  """
  def delete_by_auth_code(auth_code) when is_binary(auth_code) do
    case get_by_auth_code(auth_code) do
      {:ok, %{correlation_id: correlation_id}} ->
        delete(correlation_id)

      {:error, :not_found} ->
        Logger.debug("[OAuthSession] No session found for auth code")
        :ok

      error ->
        error
    end
  end

  # Private helpers

  defp auth_code_key(auth_code), do: "auth_code:#{auth_code}"
end
