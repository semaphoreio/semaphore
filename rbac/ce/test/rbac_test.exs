defmodule RbacTest do
  use ExUnit.Case
  use Rbac.RepoCase

  doctest Rbac

  test "greets the world" do
    assert Rbac.hello() == :world
  end
end
