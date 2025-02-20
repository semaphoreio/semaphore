defmodule Ppl.DefinitionReviser.BlocksGodfather.Test do
  use ExUnit.Case

  alias Ppl.DefinitionReviser.BlocksGodfather

  test "blocks with all unique names should pass validation" do
    definition = %{"blocks" => [%{"name" => "First block"},
                                %{"name" => "Second block"}]}

    assert {:ok, definition} == BlocksGodfather.name_blocks(definition)
  end

  test "blocks with same names should not pass validation" do
    definition = %{"blocks" => [%{"name" => "First block"},
                                %{"name" => "First block"}]}

    assert {:error, {:malformed, message}} = BlocksGodfather.name_blocks(definition)
    assert message == "There are at least two blocks with same name: First block"
  end

  test "set unique names for blocks whitouth names" do
    definition = %{"blocks" => [%{},%{}]}

    expected = %{"blocks" => [%{"name" => "Nameless block 1"},
                              %{"name" => "Nameless block 2"}]}
    assert {:ok, expected} == BlocksGodfather.name_blocks(definition)
  end

  test "set unique names only for blocks whitouth names" do
    definition = %{"blocks" => [%{"name" => "First block"},%{}]}

    expected = %{"blocks" => [%{"name" => "First block"},
                              %{"name" => "Nameless block 1"}]}
    assert {:ok, expected} == BlocksGodfather.name_blocks(definition)
  end

  test "when default name is taken, use one with increased index for nameless blocks" do
    definition = %{"blocks" => [%{"name" => "First block"}, %{},
                                %{"name" => "Nameless block 1"}]}

    expected = %{"blocks" => [%{"name" => "First block"},
                              %{"name" => "Nameless block 2"},
                              %{"name" => "Nameless block 1"}]}
    assert {:ok, expected} == BlocksGodfather.name_blocks(definition)
  end
end
