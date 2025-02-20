defmodule JobMatrix.CartesianTest do
  use ExUnit.Case

  alias JobMatrix.Cartesian

  doctest JobMatrix.Cartesian


  test "send 'list' and 'acc' values of various types - pass" do
    list = [2, :two]
    acc = [%{name: "one", value: "1"}, %{name: "one", value: 1.0}]
    assert {:ok, result} = Cartesian.product("two", list, acc)

    expected_result = [[%{name: "one", value: "1"}, %{name: "two", value: 2}],
                       [%{name: "one", value: "1"}, %{name: "two", value: :two}],
                       [%{name: "one", value: 1.0}, %{name: "two", value: 2}],
                       [%{name: "one", value: 1.0}, %{name: "two", value: :two}]]

    assert result == expected_result
  end

  test "send 'name' of invalid type - fail" do
    assert {:error, {:malformed, msg}} = Cartesian.product(:INVALID_TYPE_NAME, ["4"], [])
    assert msg == "'name' parameter must be of type String."
  end

  test "send 'list' of invalid type - fail" do
    assert {:error, {:malformed, msg}} = Cartesian.product("valid_name", :INVALID_TYPE_LIST, [])
    assert msg == "'list' parameter must be non-empty List."
  end

  test "send empty 'list' - fail" do
    assert {:error, {:malformed, msg}} = Cartesian.product("valid_name", [], [])
    assert msg == "'list' parameter must be non-empty List."
  end

  test "send 'acc' of invalid type - fail" do
    assert {:error, {:malformed, msg}} = Cartesian.product("valid_name", ["1.3", "1.4"], :INVALID_TYPE_ACC)
    assert msg == "'acc' parameter must be of type List."
  end

end
