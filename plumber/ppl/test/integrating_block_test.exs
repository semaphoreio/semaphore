defmodule IntegratingBlock.Test do
  use ExUnit.Case

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  test "testing Block app'ss availability by calling Block's version method" do
    version = Block.version()
    assert Regex.match?(~r/[0-9]\.[0-9]\.[0-9]/, version)
  end
end
