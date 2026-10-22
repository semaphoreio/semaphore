defmodule Zebra.Lock do
  @doc """
  Tries to acquire a DB level advisory lock.

  If the key is acquired, the provided 'fun' callback is executed.
  Otherwise, the lock is skipped and the function returns immidiately.

  Example:

  Repo.transition(fn ->
    Zebra.Lock.advisory("test", fn ->
      # .... executing magic ....
    end)
  end)
  """
  def advisory(name, fun) do
    key = :erlang.crc32(name)
    query = "SELECT pg_try_advisory_xact_lock(#{key});"

    {:ok, %Postgrex.Result{rows: [[locked]]}} = Zebra.LegacyRepo.query(query)

    if locked do
      {:lock_obtained, fun.()}
    else
      {:lock_skipped, nil}
    end
  end

  @doc """
  Like advisory/2, but waits up to `timeout_ms` for the lock to be released
  instead of skipping right away. Must run inside a transaction.

  Returns {:lock_obtained, result}, or rolls the transaction back with
  :lock_timeout when the lock wasn't released in time.
  """
  def advisory_wait(name, timeout_ms, fun) when is_integer(timeout_ms) and timeout_ms > 0 do
    key = :erlang.crc32(name)

    Zebra.LegacyRepo.query!("SET LOCAL lock_timeout = #{timeout_ms}")

    case Zebra.LegacyRepo.query("SELECT pg_advisory_xact_lock(#{key});") do
      {:ok, _} ->
        # don't let the wait limit apply to the locks taken by `fun`
        Zebra.LegacyRepo.query!("SET LOCAL lock_timeout TO DEFAULT")
        {:lock_obtained, fun.()}

      {:error, %Postgrex.Error{postgres: %{code: :lock_not_available}}} ->
        Zebra.LegacyRepo.rollback(:lock_timeout)
    end
  end
end
