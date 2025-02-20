defmodule DefinitionValidator.YamlStringParser.Test do
  use ExUnit.Case
  doctest DefinitionValidator.YamlStringParser

  alias DefinitionValidator.YamlStringParser

  test "pass" do
    assert {:ok, _} = YamlStringParser.parse("""
      foo: 123
      bar: "baz"
      """
    )
  end

  test "fail - wrong file format" do
    assert {:error, "malformed yaml"} = YamlStringParser.parse("""
      foo: 123
        bar: "baz"
      """
    )
  end
end
