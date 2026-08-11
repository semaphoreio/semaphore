defmodule Guard.McpOAuth.AuthCodeCleaner do
  use Quantum, otp_app: :guard

  require Logger

  def process do
    Watchman.benchmark("guard.mcp_oauth_auth_code_cleaner", fn ->
      Logger.info("Starting MCP OAuth auth code cleanup")
      {count, _} = Guard.Store.McpOAuthAuthCode.cleanup_expired()
      Logger.info("MCP OAuth auth code cleanup finished, removed #{count} expired codes")
      :ok
    end)
  end
end
