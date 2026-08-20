defmodule Guard.McpOAuth.Token.Test do
  use Guard.RepoCase, async: false

  import Ecto.Query

  alias Guard.McpOAuth.Token
  alias Guard.Repo
  alias Guard.Store.McpOAuthRefreshToken

  @client_id "mcp_test_client"

  setup do
    user_id = Ecto.UUID.generate()
    {:ok, _user} = Support.Factories.RbacUser.insert(user_id)

    System.put_env("MCP_OAUTH_JWT_KEYS", "test-secret-key-for-mcp-oauth-tests")

    on_exit(fn ->
      System.delete_env("MCP_OAUTH_JWT_KEYS")
    end)

    {:ok, user_id: user_id}
  end

  defp issue(user_id, overrides \\ %{}) do
    McpOAuthRefreshToken.issue(Map.merge(%{client_id: @client_id, user_id: user_id}, overrides))
  end

  defp refresh(token) do
    Token.exchange(%{
      "grant_type" => "refresh_token",
      "refresh_token" => token,
      "client_id" => @client_id
    })
  end

  defp row(token) do
    hash = McpOAuthRefreshToken.hash(token)
    Repo.get_by!(Guard.Repo.McpOAuthRefreshToken, token_hash: hash)
  end

  defp active_in_family(family_id) do
    Guard.Repo.McpOAuthRefreshToken
    |> where([rt], rt.family_id == ^family_id and is_nil(rt.revoked_at))
    |> Repo.all()
  end

  defp seconds_from_now(seconds) do
    DateTime.utc_now() |> DateTime.add(seconds, :second) |> DateTime.truncate(:second)
  end

  describe "exchange/1 with grant_type=refresh_token" do
    test "rotation stays in the family and keeps its absolute deadline", %{user_id: user_id} do
      {:ok, token, record} = issue(user_id)

      assert {:ok, response} = refresh(token)

      rotated = row(response["refresh_token"])
      assert rotated.family_id == record.family_id
      assert rotated.family_expires_at == record.family_expires_at
    end

    test "a family past its absolute deadline is rejected", %{user_id: user_id} do
      # The token's own expiry is still in the future, so only the family
      # deadline can reject this: a stolen family that keeps rotating cannot
      # outlive the authorization that created it.
      {:ok, token, _record} =
        issue(user_id, %{
          family_expires_at: seconds_from_now(-60),
          expires_at: seconds_from_now(3600)
        })

      assert {:error, error} = refresh(token)
      assert error["error"] == "invalid_grant"
    end

    test "concurrent refreshes of one token: exactly one wins", %{user_id: user_id} do
      {:ok, token, record} = issue(user_id)

      # The used-check, the mark-used and the successor insert are folded into
      # a single SELECT FOR UPDATE transaction, so of N concurrent refreshes
      # exactly one consumes the token. The rest serialize behind the row lock,
      # find it used, and trip replay detection.
      results =
        1..5
        |> Enum.map(fn _ -> Task.async(fn -> refresh(token) end) end)
        |> Enum.map(&Task.await(&1, 5_000))

      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert Enum.count(results, &match?({:error, %{"error" => "invalid_grant"}}, &1)) == 4

      # Replay revokes the whole family, including the successor the winning
      # refresh handed out, so the losers cannot be replayed either.
      assert active_in_family(record.family_id) == []
      refute is_nil(row(token).used_at)
    end
  end
end
