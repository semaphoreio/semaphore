defmodule Badges.CacheTest do
  use ExUnit.Case

  test "it caches values when key is in parts" do
    assert Badges.Cache.fetch!(["t1", "t3"], :timer.seconds(1), fn -> "A" end) == "A"
    assert Badges.Cache.fetch!(["t1", "t3"], :timer.seconds(1), fn -> "B" end) == "A"
  end

  test "it caches values" do
    assert Badges.Cache.fetch!("t1", :timer.seconds(1), fn -> "A" end) == "A"
    assert Badges.Cache.fetch!("t1", :timer.seconds(1), fn -> "B" end) == "A"
  end

  test "timeout" do
    assert Badges.Cache.fetch!("t2", :timer.seconds(3), fn -> "A" end) == "A"

    # cached
    assert Badges.Cache.fetch!("t2", :timer.seconds(3), fn -> "B" end) == "A"

    :timer.sleep(5000)

    # cache-recalculated
    assert Badges.Cache.fetch!("t2", :timer.seconds(3), fn -> "B" end) == "B"
  end

  test "nil is not cached" do
    assert Badges.Cache.fetch!("t3", :timer.seconds(5), fn -> nil end) == nil
    assert Badges.Cache.fetch!("t3", :timer.seconds(5), fn -> "B" end) == "B"
  end
end
