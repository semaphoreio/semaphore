defmodule Guard.Store.McpOAuthRefreshToken.Test do
  use Guard.RepoCase, async: false

  alias Guard.Store.McpOAuthRefreshToken
  alias Guard.Repo

  @client_id "mcp_test_client"

  setup do
    user_id = Ecto.UUID.generate()
    {:ok, _user} = Support.Factories.RbacUser.insert(user_id)
    {:ok, user_id: user_id}
  end

  defp issue(user_id, overrides \\ %{}) do
    McpOAuthRefreshToken.issue(Map.merge(%{client_id: @client_id, user_id: user_id}, overrides))
  end

  defp expired_at(seconds_ago) do
    DateTime.utc_now() |> DateTime.add(-seconds_ago, :second) |> DateTime.truncate(:second)
  end

  describe "issue/1" do
    test "returns the plaintext token and stores only its hash", %{user_id: user_id} do
      assert {:ok, token, record} = issue(user_id)

      assert is_binary(token)
      assert byte_size(token) > 0
      assert record.token_hash == McpOAuthRefreshToken.hash(token)
      refute record.token_hash == token
      assert record.client_id == @client_id
      assert record.user_id == user_id
      assert is_nil(record.used_at)
      assert is_nil(record.revoked_at)
    end

    test "starts a new family when none is given", %{user_id: user_id} do
      {:ok, _, first} = issue(user_id)
      {:ok, _, second} = issue(user_id)

      assert first.family_id != second.family_id
    end

    test "keeps the given family", %{user_id: user_id} do
      {:ok, _, first} = issue(user_id)
      {:ok, _, second} = issue(user_id, %{family_id: first.family_id})

      assert second.family_id == first.family_id
    end

    test "defaults expiry to the configured TTL", %{user_id: user_id} do
      {:ok, _, record} = issue(user_id)

      ttl = DateTime.diff(record.expires_at, DateTime.utc_now())
      assert_in_delta ttl, McpOAuthRefreshToken.ttl_seconds(), 10
    end

    test "missing client_id returns an error", %{user_id: user_id} do
      params = %{user_id: user_id, client_id: nil}

      assert {:error, changeset} = McpOAuthRefreshToken.issue(params)
      refute changeset.valid?
    end
  end

  describe "lock_token/2" do
    test "locks a token by plaintext value", %{user_id: user_id} do
      {:ok, token, record} = issue(user_id)

      {:ok, result} =
        Repo.transaction(fn -> McpOAuthRefreshToken.lock_token(token, @client_id) end)

      assert {:ok, locked} = result
      assert locked.id == record.id
    end

    test "wrong client_id returns not_found", %{user_id: user_id} do
      {:ok, token, _} = issue(user_id)

      {:ok, result} =
        Repo.transaction(fn -> McpOAuthRefreshToken.lock_token(token, "other-client") end)

      assert {:error, :not_found} = result
    end

    test "unknown token returns not_found" do
      {:ok, result} =
        Repo.transaction(fn -> McpOAuthRefreshToken.lock_token("nonexistent", @client_id) end)

      assert {:error, :not_found} = result
    end

    test "returns used and expired tokens so replay can be detected", %{user_id: user_id} do
      {:ok, token, record} = issue(user_id, %{expires_at: expired_at(3600)})
      {:ok, _} = McpOAuthRefreshToken.mark_used(record)

      {:ok, result} =
        Repo.transaction(fn -> McpOAuthRefreshToken.lock_token(token, @client_id) end)

      assert {:ok, locked} = result
      refute is_nil(locked.used_at)
    end
  end

  describe "revoke_family/1" do
    test "revokes active tokens in the family and leaves others alone", %{user_id: user_id} do
      {:ok, _, first} = issue(user_id)
      {:ok, _, second} = issue(user_id, %{family_id: first.family_id})
      {:ok, _, unrelated} = issue(user_id)

      assert {2, _} = McpOAuthRefreshToken.revoke_family(first.family_id)

      refute is_nil(Repo.get!(Guard.Repo.McpOAuthRefreshToken, first.id).revoked_at)
      refute is_nil(Repo.get!(Guard.Repo.McpOAuthRefreshToken, second.id).revoked_at)
      assert is_nil(Repo.get!(Guard.Repo.McpOAuthRefreshToken, unrelated.id).revoked_at)
    end

    test "is idempotent", %{user_id: user_id} do
      {:ok, _, record} = issue(user_id)

      assert {1, _} = McpOAuthRefreshToken.revoke_family(record.family_id)
      assert {0, _} = McpOAuthRefreshToken.revoke_family(record.family_id)
    end
  end

  describe "cleanup_expired/0" do
    test "deletes expired tokens and keeps live ones, used or not", %{user_id: user_id} do
      {:ok, _, expired} = issue(user_id, %{expires_at: expired_at(3600)})
      {:ok, _, live} = issue(user_id)
      {:ok, _, live_used} = issue(user_id)
      {:ok, _} = McpOAuthRefreshToken.mark_used(live_used)

      assert {1, _} = McpOAuthRefreshToken.cleanup_expired()

      remaining_ids = Enum.map(Repo.all(Guard.Repo.McpOAuthRefreshToken), & &1.id)

      assert Enum.sort(remaining_ids) == Enum.sort([live.id, live_used.id])
      refute expired.id in remaining_ids
    end
  end

  describe "generate_token/0" do
    test "produces unique, non-empty values" do
      token = McpOAuthRefreshToken.generate_token()

      assert is_binary(token)
      assert byte_size(token) > 0
      assert token != McpOAuthRefreshToken.generate_token()
    end
  end
end
