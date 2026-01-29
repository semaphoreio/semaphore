defmodule Guard.McpOAuth.Metadata do
  @moduledoc """
  OAuth 2.0 Authorization Server Metadata (RFC 8414) for MCP OAuth.
  """

  @doc """
  Returns the authorization server metadata as a map.
  """
  @spec get_metadata() :: map()
  def get_metadata do
    domain = Application.fetch_env!(:guard, :base_domain)
    issuer = "https://mcp.#{domain}/mcp/oauth"

    %{
      "issuer" => issuer,
      "authorization_endpoint" => "#{issuer}/authorize",
      "token_endpoint" => "#{issuer}/token",
      "registration_endpoint" => "#{issuer}/register",
      "response_types_supported" => ["code"],
      "response_modes_supported" => ["query"],
      "grant_types_supported" => ["authorization_code"],
      "code_challenge_methods_supported" => ["S256"],
      "token_endpoint_auth_methods_supported" => ["none"],
      "scopes_supported" => ["mcp"],
      "service_documentation" => "https://docs.semaphoreci.com/mcp"
    }
  end

  @doc """
  Returns the metadata as JSON string.
  """
  @spec get_metadata_json() :: String.t()
  def get_metadata_json do
    Jason.encode!(get_metadata())
  end
end
