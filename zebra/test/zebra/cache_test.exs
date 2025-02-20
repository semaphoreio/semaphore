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
end
