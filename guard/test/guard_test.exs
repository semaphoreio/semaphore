defmodule GuardTest do
  use Guard.RepoCase
  doctest Guard

  test "greets the world" do
    assert Guard.hello() == :world
  end
end
