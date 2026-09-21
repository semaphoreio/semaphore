defmodule Guard.CLIAuth.AuthCodeCleanerTest do
  use Guard.RepoCase, async: false

  alias Guard.Store.CliAuthCode
  alias Guard.Repo

  defp expires_in(seconds) do
    DateTime.utc_now() |> DateTime.add(seconds, :second) |> DateTime.truncate(:second)
  end

  describe "process/0" do
    test "deletes expired cli_auth_codes rows" do
      {:ok, _expired} =
        CliAuthCode.create(%{
          flow_type: "device",
          status: "pending",
          device_code_hash: CliAuthCode.hash("cleaner-expired-1"),
          user_code_hash: CliAuthCode.hash("CLEANER1"),
          expires_at: expires_in(-3600)
        })

      {:ok, _also_expired} =
        CliAuthCode.create(%{
          flow_type: "device",
          status: "pending",
          device_code_hash: CliAuthCode.hash("cleaner-expired-2"),
          user_code_hash: CliAuthCode.hash("CLEANER2"),
          expires_at: expires_in(-60)
        })

      {:ok, live} =
        CliAuthCode.create(%{
          flow_type: "device",
          status: "pending",
          device_code_hash: CliAuthCode.hash("cleaner-live"),
          user_code_hash: CliAuthCode.hash("CLEANER3"),
          expires_at: expires_in(900)
        })

      assert :ok = Guard.CLIAuth.AuthCodeCleaner.process()

      remaining = Repo.all(Guard.Repo.CliAuthCode)
      assert length(remaining) == 1
      assert hd(remaining).id == live.id
    end

    test "keeps valid (non-expired) rows" do
      {:ok, _} =
        CliAuthCode.create(%{
          flow_type: "device",
          status: "pending",
          device_code_hash: CliAuthCode.hash("cleaner-live-a"),
          user_code_hash: CliAuthCode.hash("CLEANRA1"),
          expires_at: expires_in(900)
        })

      {:ok, _} =
        CliAuthCode.create(%{
          flow_type: "device",
          status: "pending",
          device_code_hash: CliAuthCode.hash("cleaner-live-b"),
          user_code_hash: CliAuthCode.hash("CLEANRB1"),
          expires_at: expires_in(900)
        })

      assert :ok = Guard.CLIAuth.AuthCodeCleaner.process()

      assert length(Repo.all(Guard.Repo.CliAuthCode)) == 2
    end

    test "returns :ok on an empty table" do
      assert :ok = Guard.CLIAuth.AuthCodeCleaner.process()
    end
  end
end
