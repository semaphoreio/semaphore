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
end
