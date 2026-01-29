defmodule Guard.McpOAuth.Authorize do
  @moduledoc """
  OAuth 2.0 Authorization Endpoint for MCP OAuth.

  Handles the authorization request, validates parameters, and redirects
  to the grant selection UI for user consent.
  """

  require Logger

  alias Guard.Store.McpOAuthClient

  @doc """
  Validates an authorization request and returns parameters for consent flow.

  ## Parameters
  - params: Map with authorization request parameters
    - response_type (required): Must be "code"
    - client_id (required): Registered client ID
    - redirect_uri (required): Must match registered URI
    - code_challenge (required): PKCE challenge
    - code_challenge_method (required): Must be "S256"
    - state (optional): Client state for CSRF protection
    - scope (optional): Requested scopes

  ## Returns
  - `{:ok, validated_params}` on success
  - `{:error, error_response}` on failure (with redirect info if applicable)
  """
  @spec validate_request(map()) :: {:ok, map()} | {:error, map()}
  def validate_request(params) do
    with :ok <- validate_response_type(params),
         {:ok, client} <- validate_client(params),
         :ok <- validate_redirect_uri(client, params),
         :ok <- validate_pkce(params) do
      {:ok,
       %{
         client_id: params["client_id"],
         client_name: client.client_name || params["client_id"],
         redirect_uri: params["redirect_uri"],
         code_challenge: params["code_challenge"],
         state: params["state"],
         scope: params["scope"] || "mcp"
       }}
    end
  end

  @doc """
  Builds an authorization error redirect URL.
  """
  @spec build_error_redirect(String.t(), String.t(), String.t(), String.t() | nil) :: String.t()
  def build_error_redirect(redirect_uri, error, description, state \\ nil) do
    params = [
      {"error", error},
      {"error_description", description}
    ]

    params = if state, do: params ++ [{"state", state}], else: params

    query = URI.encode_query(params)
    "#{redirect_uri}?#{query}"
  end

  @doc """
  Builds a successful authorization redirect URL with code.
  """
  @spec build_success_redirect(String.t(), String.t(), String.t() | nil) :: String.t()
  def build_success_redirect(redirect_uri, code, state \\ nil) do
    params = [{"code", code}]
    params = if state, do: params ++ [{"state", state}], else: params

    query = URI.encode_query(params)
    "#{redirect_uri}?#{query}"
  end

  # Private functions

  defp validate_response_type(params) do
    case params["response_type"] do
      "code" ->
        :ok

      nil ->
        {:error, direct_error("invalid_request", "response_type is required")}

      other ->
        {:error, direct_error("unsupported_response_type", "response_type must be 'code', got '#{other}'")}
    end
  end

  defp validate_client(params) do
    case params["client_id"] do
      nil ->
        {:error, direct_error("invalid_request", "client_id is required")}

      client_id ->
        case McpOAuthClient.find_by_client_id(client_id) do
          {:ok, client} ->
            {:ok, client}

          {:error, :not_found} ->
            {:error, direct_error("invalid_client", "Unknown client_id")}
        end
    end
  end

  defp validate_redirect_uri(client, params) do
    case params["redirect_uri"] do
      nil ->
        {:error, direct_error("invalid_request", "redirect_uri is required")}

      redirect_uri ->
        if McpOAuthClient.valid_redirect_uri?(client, redirect_uri) do
          :ok
        else
          {:error, direct_error("invalid_request", "redirect_uri does not match registered URIs")}
        end
    end
  end

  defp validate_pkce(params) do
    cond do
      is_nil(params["code_challenge"]) ->
        {:error, redirect_error(params, "invalid_request", "code_challenge is required")}

      params["code_challenge_method"] != "S256" ->
        {:error, redirect_error(params, "invalid_request", "code_challenge_method must be S256")}

      true ->
        :ok
    end
  end

  # Direct errors are returned before redirect_uri is validated
  defp direct_error(error, description) do
    %{
      type: :direct,
      error: error,
      error_description: description
    }
  end

  # Redirect errors can be sent back to the client via redirect_uri
  defp redirect_error(params, error, description) do
    %{
      type: :redirect,
      redirect_uri: params["redirect_uri"],
      state: params["state"],
      error: error,
      error_description: description
    }
  end
end
