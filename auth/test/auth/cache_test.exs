defmodule Auth.CacheTest do
  use ExUnit.Case

  doctest Auth

  test "it caches values" do
    assert Auth.Cache.fetch!("t1", :timer.seconds(1), fn -> "A" end) == "A"
    assert Auth.Cache.fetch!("t1", :timer.seconds(1), fn -> "B" end) == "A"
  end

  test "timeout" do
    assert Auth.Cache.fetch!("t2", :timer.seconds(1), fn -> "A" end) == "A"

    :timer.sleep(5000)

    assert Auth.Cache.fetch!("t2", :timer.seconds(1), fn -> "B" end) == "B"
  end

  test "nil is not cached" do
    assert Auth.Cache.fetch!("t3", :timer.seconds(5), fn -> nil end) == nil
    assert Auth.Cache.fetch!("t3", :timer.seconds(5), fn -> "B" end) == "B"
  end
end
