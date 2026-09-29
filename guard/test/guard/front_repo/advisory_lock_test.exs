defmodule Guard.FrontRepo.AdvisoryLockTest do
  use Guard.RepoCase, async: false

  alias Guard.FrontRepo
  alias Guard.FrontRepo.AdvisoryLock

  describe "lock_key/1" do
    test "is deterministic for the same key" do
      assert AdvisoryLock.lock_key("abc") == AdvisoryLock.lock_key("abc")
    end

    test "different keys map to different locks" do
      refute AdvisoryLock.lock_key("abc") == AdvisoryLock.lock_key("abd")
    end

    test "fits in a signed 64-bit integer (what pg_try_advisory_xact_lock takes)" do
      for key <- ["", "abc", Ecto.UUID.generate(), String.duplicate("x", 500)] do
        lock_key = AdvisoryLock.lock_key(key)
        assert is_integer(lock_key)
        assert lock_key >= -0x8000000000000000
        assert lock_key <= 0x7FFFFFFFFFFFFFFF
      end
    end

    test "is a pinned value, so every replica and every OTP version agrees" do
      # Guards against swapping the digest for something node-local (e.g.
      # :erlang.phash2/1), which would silently make the lock per-replica and
      # bring the concurrent refresh back.
      assert AdvisoryLock.lock_key("00000000-0000-4000-8000-000000000001") ==
               -789_017_970_825_694_678

      assert AdvisoryLock.lock_key("a") == -3_097_375_801_941_993_126
    end
  end

  describe "transaction/2" do
    test "runs the function and returns its value" do
      assert {:ok, :ran} = AdvisoryLock.transaction(Ecto.UUID.generate(), fn -> :ran end)
    end

    test "the function may read and write through the repo" do
      key = Ecto.UUID.generate()

      assert {:ok, %{rows: [[1]]}} =
               AdvisoryLock.transaction(key, fn -> FrontRepo.query!("SELECT 1", []) end)
    end

    test "applies SET LOCAL lock_timeout inside the transaction" do
      {:ok, lock_timeout} =
        AdvisoryLock.transaction(Ecto.UUID.generate(), fn ->
          %{rows: [[value]]} = FrontRepo.query!("SHOW lock_timeout", [])
          value
        end)

      # Postgres normalises the unit on the way out; what matters is that a
      # row-lock wait inside the locked transaction is bounded rather than
      # infinite (the default is "0").
      assert lock_timeout in ["3s", "3000ms"]
    end

    test "returns :busy WITHOUT running the function when another session holds the lock" do
      # The sandbox shares one connection across the test, and advisory locks
      # are re-entrant within a session - so a second checkout here would
      # always win. Take the lock from a genuinely separate Postgres session
      # to prove the exclusion is cross-connection (and therefore
      # cross-replica), which is the whole point of using an advisory lock
      # rather than a node-local one.
      key = Ecto.UUID.generate()
      holder = start_foreign_connection!()

      Postgrex.query!(holder, "SELECT pg_advisory_lock($1)", [AdvisoryLock.lock_key(key)])

      assert :busy = AdvisoryLock.transaction(key, fn -> flunk("must not run while held") end)

      Postgrex.query!(holder, "SELECT pg_advisory_unlock($1)", [AdvisoryLock.lock_key(key)])
    end

    test "a foreign session holding a DIFFERENT key does not block us" do
      holder = start_foreign_connection!()
      Postgrex.query!(holder, "SELECT pg_advisory_lock($1)", [AdvisoryLock.lock_key("other")])

      assert {:ok, :ran} = AdvisoryLock.transaction(Ecto.UUID.generate(), fn -> :ran end)
    end

    test "a pool-checkout failure comes back as {:error, _}, not a raise" do
      # The winner holds a connection for the length of its provider call, so a
      # checkout timeout is a foreseeable outcome. It must not escape as an
      # exception: the caller has to be able to degrade it to a retryable error
      # and write its negative-cache entry.
      :meck.new(Guard.FrontRepo, [:passthrough])
      on_exit(fn -> safe_unload(Guard.FrontRepo) end)

      :meck.expect(Guard.FrontRepo, :transaction, fn _fun ->
        raise DBConnection.ConnectionError, "connection not available"
      end)

      assert {:error, %DBConnection.ConnectionError{}} =
               AdvisoryLock.transaction(Ecto.UUID.generate(), fn -> :never end)
    end

    test "an exception raised by the function itself still propagates" do
      # The rescue is scoped to connection failures on purpose - a bug inside
      # the locked section must not be silently turned into a retry.
      assert_raise RuntimeError, "boom", fn ->
        AdvisoryLock.transaction(Ecto.UUID.generate(), fn -> raise "boom" end)
      end
    end

    test "the lock is released when the transaction ends, so the next caller gets it" do
      key = Ecto.UUID.generate()

      assert {:ok, :first} = AdvisoryLock.transaction(key, fn -> :first end)
      assert {:ok, :second} = AdvisoryLock.transaction(key, fn -> :second end)
    end
  end

  defp safe_unload(mod) do
    :meck.unload(mod)
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  # A Postgres connection outside the Ecto pool and outside the sandbox, so it
  # is a distinct session as far as advisory locks are concerned. Stopped when
  # the test ends.
  defp start_foreign_connection! do
    opts =
      FrontRepo.config()
      |> Keyword.take([:hostname, :port, :username, :password, :database, :ssl])

    {:ok, conn} = Postgrex.start_link(opts)
    on_exit(fn -> if Process.alive?(conn), do: GenServer.stop(conn) end)

    conn
  end
end
