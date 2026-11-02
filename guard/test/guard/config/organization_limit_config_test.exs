defmodule Guard.Config.OrganizationLimitConfigTest do
  use ExUnit.Case, async: false

  @runtime_config Path.expand("../../../config/runtime.exs", __DIR__)
  @var "ORGANIZATION_LIMIT_PER_CREATOR"

  setup do
    previous = System.get_env(@var)

    on_exit(fn ->
      if previous == nil, do: System.delete_env(@var), else: System.put_env(@var, previous)
    end)

    :ok
  end

  defp limit_for(value) do
    if value == nil, do: System.delete_env(@var), else: System.put_env(@var, value)

    @runtime_config
    |> Config.Reader.read!(env: :test, target: :host)
    |> Keyword.fetch!(:guard)
    |> Keyword.fetch!(:organization_limit_per_creator)
  end

  test "defaults to 3 when unset or blank" do
    assert limit_for(nil) == 3
    assert limit_for("") == 3
    assert limit_for("   ") == 3
  end

  test "accepts non-negative integers, ignoring surrounding whitespace" do
    assert limit_for("5") == 5
    assert limit_for(" 7\n") == 7
    assert limit_for("0") == 0
  end

  test "raises a clear error for invalid values" do
    for value <- ["-1", "abc", "3.5", "3abc"] do
      assert_raise RuntimeError, ~r/ORGANIZATION_LIMIT_PER_CREATOR must be 0/, fn ->
        limit_for(value)
      end
    end
  end
end
