defmodule DefinitionValidator.YamlMapValidator.Test do
  use ExUnit.Case
  doctest DefinitionValidator.YamlMapValidator

  alias DefinitionValidator.YamlMapValidator

  test "valid" do
    task = %{"jobs" => [%{"commands" => ["echo foo"]}]}
    blocks = [%{"task" => task}]
    agent = %{"machine" => %{"type" => "foo", "os_image" => "bar"}}
    ppl = %{"version" => "v1.0", "blocks" => blocks, "agent" => agent}
    assert YamlMapValidator.validate_yaml(ppl) ==
      {:ok, ppl}
  end

  test "empty map" do
    {:error, {:malformed, reason}} = YamlMapValidator.validate_yaml(%{})
    String.contains?(reason, "version")
    true
  end

  test "empty string" do
    {:error, {:malformed, reason}} = YamlMapValidator.validate_yaml("")
    assert {:expected_map, _} = reason
  end
end
