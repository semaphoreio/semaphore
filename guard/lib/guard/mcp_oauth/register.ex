defmodule Guard.McpOAuth.Register do
  @moduledoc """
  OAuth 2.0 Dynamic Client Registration (RFC 7591) for MCP OAuth.
  """

  require Logger

  alias Guard.Store.McpOAuthClient

  @doc """
  Registers a new OAuth client.

  ## Parameters
  - client_metadata: Map with client registration metadata
    - redirect_uris (required): List of redirect URIs
    - client_name (optional): Human-readable client name

  ## Returns
  - `{:ok, response}` with client credentials
  - `{:error, error_response}` on failure
  """
  @spec register(map()) :: {:ok, map()} | {:error, map()}
  def register(client_metadata) do
    with :ok <- validate_metadata(client_metadata),
         {:ok, client} <- create_client(client_metadata) do
      {:ok, build_response(client)}
    end
  end

  defp validate_metadata(metadata) do
    cond do
      !is_list(metadata["redirect_uris"]) || Enum.empty?(metadata["redirect_uris"]) ->
        {:error,
         error_response(
           "invalid_redirect_uri",
           "redirect_uris is required and must be a non-empty array"
         )}

      !Enum.all?(metadata["redirect_uris"], &valid_redirect_uri?/1) ->
        {:error, error_response("invalid_redirect_uri", "All redirect_uris must be valid URIs")}

      true ->
        :ok
    end
  end

  defp valid_redirect_uri?(uri) when is_binary(uri) do
    case URI.parse(uri) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
        true

      # Allow localhost with any scheme for development
      %URI{scheme: scheme, host: "localhost"} when not is_nil(scheme) ->
        true

      # Allow loopback addresses
      %URI{scheme: scheme, host: "127.0.0.1"} when not is_nil(scheme) ->
        true

      _ ->
        false
    end
  end

  defp valid_redirect_uri?(_), do: false

  defp create_client(metadata) do
    client_id = generate_client_id()

    params = %{
      client_id: client_id,
      client_name: metadata["client_name"],
      redirect_uris: metadata["redirect_uris"]
    }

    case McpOAuthClient.create(params) do
      {:ok, client} ->
        Logger.info("[McpOAuth.Register] Created client #{client_id}")
        {:ok, client}

      {:error, changeset} ->
        Logger.error("[McpOAuth.Register] Failed to create client: #{inspect(changeset)}")
        {:error, error_response("server_error", "Failed to create client")}
    end
  end

  defp generate_client_id do
    "mcp_" <> (:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false))
  end

  defp build_response(client) do
    domain = Application.fetch_env!(:guard, :base_domain)

    %{
      "client_id" => client.client_id,
      "client_name" => client.client_name,
      "redirect_uris" => client.redirect_uris,
      "grant_types" => ["authorization_code"],
      "response_types" => ["code"],
      "token_endpoint_auth_method" => "none",
      "scope" => "mcp",
      "registration_client_uri" => "https://mcp.#{domain}/mcp/oauth/register/#{client.client_id}"
    }
  end

  defp error_response(error, description) do
    %{
      "error" => error,
      "error_description" => description
    }
  end
end
