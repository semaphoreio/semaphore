defmodule Guard.Store.McpOAuthAuthCode.Test do
  use Guard.RepoCase, async: false

  alias Guard.Store.McpOAuthAuthCode
  alias Guard.Repo

  setup do
    user_id = Ecto.UUID.generate()
    {:ok, _user} = Support.Factories.RbacUser.insert(user_id)
    {:ok, user_id: user_id}
  end

  defp valid_params(user_id, overrides \\ %{}) do
    Support.Factories.McpOAuthAuthCode.valid_params(user_id, overrides)
  end

  describe "create/1" do
    test "with valid params creates an auth code", %{user_id: user_id} do
      params = valid_params(user_id)
      assert {:ok, auth_code} = McpOAuthAuthCode.create(params)

      assert auth_code.code == params.code
      assert auth_code.client_id == params.client_id
      assert auth_code.user_id == user_id
      assert auth_code.redirect_uri == params.redirect_uri
      assert auth_code.code_challenge == params.code_challenge
      assert auth_code.expires_at == params.expires_at
      assert is_nil(auth_code.used_at)
    end

    test "missing required field returns error", %{user_id: user_id} do
      params = valid_params(user_id) |> Map.delete(:code)
      assert {:error, changeset} = McpOAuthAuthCode.create(params)
      assert %{code: _} = errors_on(changeset)
    end

    test "duplicate code returns error", %{user_id: user_id} do
      params = valid_params(user_id)
      assert {:ok, _} = McpOAuthAuthCode.create(params)
      assert {:error, changeset} = McpOAuthAuthCode.create(params)
      assert %{code: _} = errors_on(changeset)
    end
  end

  describe "lock_code/2" do
    test "locks a valid unused code", %{user_id: user_id} do
      params = valid_params(user_id)
      {:ok, _} = McpOAuthAuthCode.create(params)

      {:ok, result} =
        Repo.transaction(fn ->
          McpOAuthAuthCode.lock_code(params.code, params.client_id)
        end)

      assert {:ok, auth_code} = result
      assert auth_code.code == params.code
    end

    test "wrong client_id returns error", %{user_id: user_id} do
      params = valid_params(user_id)
      {:ok, _} = McpOAuthAuthCode.create(params)

      {:ok, result} =
        Repo.transaction(fn ->
          McpOAuthAuthCode.lock_code(params.code, "wrong-client")
        end)

      assert {:error, :invalid_or_used} = result
    end

    test "already used code returns error", %{user_id: user_id} do
      params = valid_params(user_id, %{used_at: DateTime.utc_now() |> DateTime.truncate(:second)})
      {:ok, _} = McpOAuthAuthCode.create(params)

      {:ok, result} =
        Repo.transaction(fn ->
          McpOAuthAuthCode.lock_code(params.code, params.client_id)
        end)

      assert {:error, :invalid_or_used} = result
    end

    test "expired code returns error", %{user_id: user_id} do
      params =
        valid_params(user_id, %{
          expires_at:
            DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)
        })

      {:ok, _} = McpOAuthAuthCode.create(params)

      {:ok, result} =
        Repo.transaction(fn ->
          McpOAuthAuthCode.lock_code(params.code, params.client_id)
        end)

      assert {:error, :invalid_or_used} = result
    end

    test "nonexistent code returns error" do
      {:ok, result} =
        Repo.transaction(fn ->
          McpOAuthAuthCode.lock_code("nonexistent-code", "any-client")
        end)

      assert {:error, :invalid_or_used} = result
    end
  end

  describe "mark_code_used/1" do
    test "sets used_at on the auth code", %{user_id: user_id} do
      params = valid_params(user_id)
      {:ok, auth_code} = McpOAuthAuthCode.create(params)

      assert is_nil(auth_code.used_at)

      {:ok, result} =
        Repo.transaction(fn ->
          {:ok, locked} = McpOAuthAuthCode.lock_code(params.code, params.client_id)
          McpOAuthAuthCode.mark_code_used(locked)
        end)

      assert {:ok, used_code} = result
      assert not is_nil(used_code.used_at)
    end

    test "after marking used, lock_code returns error", %{user_id: user_id} do
      params = valid_params(user_id)
      {:ok, _auth_code} = McpOAuthAuthCode.create(params)

      Repo.transaction(fn ->
        {:ok, locked} = McpOAuthAuthCode.lock_code(params.code, params.client_id)
        {:ok, _} = McpOAuthAuthCode.mark_code_used(locked)
      end)

      {:ok, result} =
        Repo.transaction(fn ->
          McpOAuthAuthCode.lock_code(params.code, params.client_id)
        end)

      assert {:error, :invalid_or_used} = result
    end
  end

  describe "generate_code/0" do
    test "returns a non-empty string" do
      code = McpOAuthAuthCode.generate_code()
      assert is_binary(code)
      assert byte_size(code) > 0
    end

    test "produces unique values" do
      code1 = McpOAuthAuthCode.generate_code()
      code2 = McpOAuthAuthCode.generate_code()
      assert code1 != code2
    end
  end

  describe "cleanup_expired/0" do
    test "deletes expired codes and keeps non-expired", %{user_id: user_id} do
      expired_params =
        valid_params(user_id, %{
          code: "expired-code",
          expires_at:
            DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)
        })

      valid_params = valid_params(user_id, %{code: "valid-code"})

      {:ok, _} = McpOAuthAuthCode.create(expired_params)
      {:ok, _} = McpOAuthAuthCode.create(valid_params)

      {deleted_count, _} = McpOAuthAuthCode.cleanup_expired()

      assert deleted_count == 1

      remaining = Repo.all(Guard.Repo.McpOAuthAuthCode)
      assert length(remaining) == 1
      assert hd(remaining).code == "valid-code"
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
