defmodule Zebra.CacheTest do
  use ExUnit.Case

  test "it caches values" do
    assert Zebra.Cache.fetch!("t1", :timer.seconds(1), fn -> "A" end) == "A"
    assert Zebra.Cache.fetch!("t1", :timer.seconds(1), fn -> "B" end) == "A"
  end

  test "timeout" do
    assert Zebra.Cache.fetch!("t2", :timer.seconds(3), fn -> "A" end) == "A"

    # cached
    assert Zebra.Cache.fetch!("t2", :timer.seconds(3), fn -> "B" end) == "A"

    :timer.sleep(5000)

    # cache-recalculated
    assert Zebra.Cache.fetch!("t2", :timer.seconds(3), fn -> "B" end) == "B"
  end

  test "nil is not cached" do
    assert Zebra.Cache.fetch!("t3", :timer.seconds(5), fn -> nil end) == nil
    assert Zebra.Cache.fetch!("t3", :timer.seconds(5), fn -> "B" end) == "B"
  end

  test "if fallback returns {:ignore, value} it's not cached" do
    assert Zebra.Cache.fetch!("t4", :timer.seconds(10), fn -> {:ignore, "A"} end) == "A"
    assert Zebra.Cache.fetch!("t4", :timer.seconds(5), fn -> "B" end) == "B"
  end

  test "if fallback returns {:commit, value} it's cached" do
    assert Zebra.Cache.fetch!("t5", :timer.seconds(5), fn -> {:commit, "A"} end) == "A"
    assert Zebra.Cache.fetch!("t5", :timer.seconds(5), fn -> "B" end) == "A"
  end

  test "a {:commit, value} entry keeps its ttl when the caller dies mid-fetch" do
    assert_ttl_survives_caller_death("t6", fn -> {:commit, "A"} end)
  end

  test "a bare value entry keeps its ttl when the caller dies mid-fetch" do
    assert_ttl_survives_caller_death("t7", fn -> "A" end)
  end

  defp assert_ttl_survives_caller_death(key, fallback) do
    {pid, ref} =
      spawn_monitor(fn ->
        Zebra.Cache.fetch!(key, :timer.seconds(60), fn ->
          :timer.sleep(300)
          fallback.()
        end)
      end)

    :timer.sleep(100)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 1_000

    assert wait_until(fn -> Cachex.get(:zebra_cache, key) == {:ok, "A"} end),
           "fallback value was never committed to the cache"

    assert {:ok, ttl} = Cachex.ttl(:zebra_cache, key)
    assert is_integer(ttl) and ttl > 0
  end

  defp wait_until(condition, attempts \\ 20) do
    cond do
      condition.() ->
        true

      attempts == 0 ->
        false

      true ->
        :timer.sleep(100)
        wait_until(condition, attempts - 1)
    end
  end
end
