defmodule Badges.CacheKeyTest do
  use ExUnit.Case

  test "it calculates cache key" do
    assert Badges.CacheKey.calculate(["foo", "bar"]) ==
             "c3ab8ff13720e8ad9047dd39466b3c8974e592c2fa383d4a3960714caef0c4f2"
  end
end
