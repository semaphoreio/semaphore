defmodule Badges.SvgTest do
  use ExUnit.Case

  alias Badges.Svg

  describe ".render" do
    test "when badge exists => returns it" do
      {:ok, badge} = Svg.render(:pending, "semaphore")

      assert badge =~ "pending"
    end

    test "when badge doesn't exists => returns error" do
      {:error, :badge_not_found} = Svg.render(:foo, "semaphore")
    end

    test "when style doesn't exists => returns error" do
      {:error, :badge_not_found} = Svg.render(:pending, "foo")
    end
  end
end
