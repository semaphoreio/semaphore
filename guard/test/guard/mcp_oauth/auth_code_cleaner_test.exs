defmodule Guard.McpOAuth.AuthCodeCleanerTest do
  use Guard.RepoCase, async: false

  alias Guard.Store.McpOAuthAuthCode
  alias Guard.Repo

  setup do
    user_id = Ecto.UUID.generate()
    {:ok, _user} = Support.Factories.RbacUser.insert(user_id)
    {:ok, user_id: user_id}
  end

  describe "process/0" do
    test "deletes expired auth codes", %{user_id: user_id} do
      expired_at =
        DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      {:ok, _} =
        McpOAuthAuthCode.create(
          Support.Factories.McpOAuthAuthCode.valid_params(user_id, %{expires_at: expired_at})
        )

      {:ok, _} =
        McpOAuthAuthCode.create(
          Support.Factories.McpOAuthAuthCode.valid_params(user_id, %{expires_at: expired_at})
        )

      {:ok, valid_code} =
        McpOAuthAuthCode.create(Support.Factories.McpOAuthAuthCode.valid_params(user_id))

      assert :ok = Guard.McpOAuth.AuthCodeCleaner.process()

      remaining = Repo.all(Guard.Repo.McpOAuthAuthCode)
      assert length(remaining) == 1
      assert hd(remaining).code == valid_code.code
    end

    test "keeps valid (non-expired) codes", %{user_id: user_id} do
      {:ok, _} = McpOAuthAuthCode.create(Support.Factories.McpOAuthAuthCode.valid_params(user_id))
      {:ok, _} = McpOAuthAuthCode.create(Support.Factories.McpOAuthAuthCode.valid_params(user_id))

      assert :ok = Guard.McpOAuth.AuthCodeCleaner.process()

      remaining = Repo.all(Guard.Repo.McpOAuthAuthCode)
      assert length(remaining) == 2
    end

    test "returns :ok", %{user_id: user_id} do
      {:ok, _} = McpOAuthAuthCode.create(Support.Factories.McpOAuthAuthCode.valid_params(user_id))

      assert :ok = Guard.McpOAuth.AuthCodeCleaner.process()
    end

    test "handles empty table" do
      assert :ok = Guard.McpOAuth.AuthCodeCleaner.process()
    end
  end
end
