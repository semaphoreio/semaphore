defmodule DefinitionValidator.YamlMapValidator.Test do
  use ExUnit.Case
  doctest DefinitionValidator.YamlMapValidator

  alias DefinitionValidator.YamlMapValidator

  test "empty map" do
    {:error, {:malformed, reasons}} = YamlMapValidator.validate_yaml(%{})
    Enum.each(reasons, fn {msg, _} -> assert String.contains?(msg, "not present") end)
  end

  test "empty string" do
    {:error, {:malformed, reason}} = YamlMapValidator.validate_yaml("")
    assert {:expected_map, _} = reason
  end
end
