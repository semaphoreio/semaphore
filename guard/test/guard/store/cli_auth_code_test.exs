defmodule Guard.Store.CliAuthCodeTest do
  use Guard.RepoCase, async: true

  alias Guard.Store.CliAuthCode
  alias Guard.Repo

  setup do
    user_id = Ecto.UUID.generate()
    {:ok, _} = Support.Factories.RbacUser.insert(user_id)
    {:ok, user_id: user_id}
  end

  defp expires_in(seconds) do
    DateTime.utc_now() |> DateTime.add(seconds, :second) |> DateTime.truncate(:second)
  end

  describe "code generation and hashing" do
    test "generate_user_code is 8 base-20 chars with no vowels/ambiguous glyphs" do
      code = CliAuthCode.generate_user_code()
      assert byte_size(code) == 8
      assert code =~ ~r/^[BCDFGHJKLMNPQRSTVWXZ]{8}$/
    end

    test "generate_device_code and generate_code produce unique values" do
      assert CliAuthCode.generate_device_code() != CliAuthCode.generate_device_code()
      assert CliAuthCode.generate_code() != CliAuthCode.generate_code()
    end

    test "format_user_code groups as XXXX-XXXX" do
      assert CliAuthCode.format_user_code("BCDFGHJK") == "BCDF-GHJK"
    end

    test "normalize_user_code strips dashes/spaces and uppercases" do
      assert CliAuthCode.normalize_user_code("bcdf-ghjk") == "BCDFGHJK"
      assert CliAuthCode.normalize_user_code(" bc df gh jk ") == "BCDFGHJK"
    end

    test "hash is a stable sha256 hex digest" do
      assert CliAuthCode.hash("abc") == CliAuthCode.hash("abc")
      assert CliAuthCode.hash("abc") != CliAuthCode.hash("abd")
      assert String.length(CliAuthCode.hash("abc")) == 64
    end
  end

  describe "loopback rows" do
    test "lock_loopback_code returns an approved, unexpired row", %{user_id: user_id} do
      {:ok, _} =
        CliAuthCode.create(%{
          flow_type: "loopback",
          status: "approved",
          code: "loopback-code-1",
          code_challenge: "challenge",
          redirect_uri: "http://127.0.0.1:1234/cb",
          user_id: user_id,
          expires_at: expires_in(300)
        })

      {:ok, result} =
        Repo.transaction(fn -> CliAuthCode.lock_loopback_code("loopback-code-1") end)

      assert {:ok, row} = result
      assert row.code == "loopback-code-1"
    end

    test "a consumed loopback code cannot be locked", %{user_id: user_id} do
      {:ok, row} =
        CliAuthCode.create(%{
          flow_type: "loopback",
          status: "approved",
          code: "loopback-code-2",
          code_challenge: "challenge",
          redirect_uri: "http://127.0.0.1:1234/cb",
          user_id: user_id,
          expires_at: expires_in(300)
        })

      {:ok, _} = CliAuthCode.mark_consumed(row)

      {:ok, result} =
        Repo.transaction(fn -> CliAuthCode.lock_loopback_code("loopback-code-2") end)

      assert {:error, :invalid_or_used} = result
    end
  end

  describe "device rows" do
    test "find_pending_by_user_code matches the hash of a pending, unexpired code" do
      user_code = "BCDFGHJK"

      {:ok, _} =
        CliAuthCode.create(%{
          flow_type: "device",
          status: "pending",
          device_code_hash: CliAuthCode.hash("dev-code"),
          user_code_hash: CliAuthCode.hash(user_code),
          expires_at: expires_in(900)
        })

      assert {:ok, row} = CliAuthCode.find_pending_by_user_code(user_code)
      assert row.user_code_hash == CliAuthCode.hash(user_code)
      assert {:error, :not_found} = CliAuthCode.find_pending_by_user_code("MNPQRSTV")
    end
  end

  describe "cleanup_expired/0" do
    test "deletes expired rows and keeps live ones" do
      {:ok, _} =
        CliAuthCode.create(%{
          flow_type: "device",
          status: "pending",
          device_code_hash: CliAuthCode.hash("expired-dev"),
          user_code_hash: CliAuthCode.hash("EXPIREDD"),
          expires_at: expires_in(-3600)
        })

      {:ok, live} =
        CliAuthCode.create(%{
          flow_type: "device",
          status: "pending",
          device_code_hash: CliAuthCode.hash("live-dev"),
          user_code_hash: CliAuthCode.hash("LIVEEEEE"),
          expires_at: expires_in(900)
        })

      assert {1, nil} = CliAuthCode.cleanup_expired()
      assert [remaining] = Repo.all(Guard.Repo.CliAuthCode)
      assert remaining.id == live.id
    end
  end
end
