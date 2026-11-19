defmodule Guard.McpOAuth.AuthCodeCleanerTest do
  use Guard.RepoCase, async: false

  import Ecto.Query

  alias Guard.Store.McpOAuthAuthCode
  alias Guard.Repo
  alias Guard.Repo.{McpOAuthRefreshToken, McpOAuthRefreshTokenFamily}

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

    test "deletes expired and long-revoked refresh tokens, and keeps live ones", %{
      user_id: user_id
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      for client_id <- ~w(live expired-token expired-family revoked-today revoked-long-ago) do
        Guard.Store.McpOAuthRefreshToken.create(
          %Guard.Repo.McpOAuthAuthCode{client_id: client_id, user_id: user_id},
          "mcp"
        )
      end

      from(t in McpOAuthRefreshToken,
        join: f in assoc(t, :family),
        where: f.client_id == "expired-token"
      )
      |> Repo.update_all(set: [expires_at: DateTime.add(now, -1)])

      update_family("expired-family", expires_at: DateTime.add(now, -1))
      update_family("revoked-today", revoked_at: now)
      update_family("revoked-long-ago", revoked_at: DateTime.add(now, -2 * 86_400))

      assert :ok = Guard.McpOAuth.AuthCodeCleaner.process()

      families = Repo.all(from(f in McpOAuthRefreshTokenFamily, select: f.client_id))
      assert Enum.sort(families) == ~w(expired-token live revoked-today)

      tokens =
        Repo.all(
          from(t in McpOAuthRefreshToken, join: f in assoc(t, :family), select: f.client_id)
        )

      assert Enum.sort(tokens) == ~w(live revoked-today)
    end

    test "handles empty table" do
      assert :ok = Guard.McpOAuth.AuthCodeCleaner.process()
    end
  end

  defp update_family(client_id, changes) do
    from(f in McpOAuthRefreshTokenFamily, where: f.client_id == ^client_id)
    |> Repo.update_all(set: changes)
  end
end
