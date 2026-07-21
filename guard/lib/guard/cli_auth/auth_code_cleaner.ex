defmodule Guard.CLIAuth.AuthCodeCleaner do
  @moduledoc """
  Periodic cleanup for `cli_auth_codes` (see `Guard.CLIAuth`). Without this,
  every CLI sign-in attempt leaves a row behind forever — unbounded row/disk
  growth. Mirrors `Guard.McpOAuth.AuthCodeCleaner`.
  """

  use Quantum, otp_app: :guard

  require Logger

  def process do
    Watchman.benchmark("guard.cli_auth_code_cleaner", fn ->
      Logger.info("Starting CLI auth code cleanup")
      {count, _} = Guard.Store.CliAuthCode.cleanup_expired()
      Logger.info("CLI auth code cleanup finished, removed #{count} expired codes")
      :ok
    end)
  end
end
