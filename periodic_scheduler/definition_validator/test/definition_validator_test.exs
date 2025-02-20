defmodule DefinitionValidator.Test do
  use ExUnit.Case
  doctest DefinitionValidator

  test "empty definition" do
    assert {:error, {:malformed, reasons}} = DefinitionValidator.validate_yaml_string("")
    Enum.each(reasons, fn {msg, _} -> assert String.contains?(msg, "not present") end)
  end

  test "peculiar yaml definition" do
    assert {:error, {:malformed, reason}} = DefinitionValidator.validate_yaml_string("foo")
    assert {:expected_map, ppl_def} = reason
    assert ppl_def == "foo"
  end

  test "valid periodic definition passes" do
    periodic_def = File.read!("../spec/test/definitions/v1.0-complete.yml")

    assert {:ok, map} = DefinitionValidator.validate_yaml_string(periodic_def)
    assert %{"metadata" => _md, "spec" => _spec} = map
  end
end
