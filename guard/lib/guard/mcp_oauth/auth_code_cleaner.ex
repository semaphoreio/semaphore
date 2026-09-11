defmodule Guard.McpOAuth.AuthCodeCleaner do
  @moduledoc """
  Periodic sweep of expired MCP OAuth records: authorization codes and refresh
  tokens. Both tables only grow otherwise, since used rows are kept until they
  expire (a used refresh token is what makes replay detection possible).
  """

  use Quantum, otp_app: :guard

  require Logger

  def process do
    Watchman.benchmark("guard.mcp_oauth_auth_code_cleaner", fn ->
      Logger.info("Starting MCP OAuth auth code cleanup")
      {count, _} = Guard.Store.McpOAuthAuthCode.cleanup_expired()
      Logger.info("MCP OAuth auth code cleanup finished, removed #{count} expired codes")

      {token_count, _} = Guard.Store.McpOAuthRefreshToken.cleanup_expired()
      Logger.info("MCP OAuth refresh token cleanup finished, removed #{token_count} tokens")

      :ok
    end)
  end
end
