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
      # OAuth 2.0 Authorization Server Metadata (RFC 8414)
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
      "service_documentation" => "https://docs.semaphoreci.com/mcp",
      # OpenID Connect Discovery 1.0 required fields for OIDC-compliant clients
      # Note: We use HS256 (symmetric) for token signing, so JWKS returns empty keys.
      # Token validation is done server-side by the MCP resource server.
      "jwks_uri" => "#{issuer}/jwks",
      "subject_types_supported" => ["public"],
      "id_token_signing_alg_values_supported" => ["HS256"]
    }
  end

  @doc """
  Returns the metadata as JSON string.
  """
  @spec get_metadata_json() :: String.t()
  def get_metadata_json do
    Jason.encode!(get_metadata())
  end

  @doc """
  Returns the OAuth 2.1 Protected Resource Metadata (RFC 9728) as a map.
  """
  @spec get_resource_metadata() :: map()
  def get_resource_metadata do
    domain = Application.fetch_env!(:guard, :base_domain)

    %{
      resource: "https://mcp.#{domain}",
      authorization_servers: ["https://mcp.#{domain}/mcp/oauth"],
      scopes_supported: ["mcp"],
      bearer_methods_supported: ["header"],
      resource_documentation: "https://docs.semaphoreci.com/mcp"
    }
  end

  @doc """
  Returns the protected resource metadata as JSON string.
  """
  @spec get_resource_metadata_json() :: String.t()
  def get_resource_metadata_json do
    Jason.encode!(get_resource_metadata())
  end
end
