defmodule DefinitionValidator.PplBlocksDependencies.Test do
  use ExUnit.Case

  alias DefinitionValidator.PplBlocksDependencies, as: Deps

  defp block(name, deps), do: %{"name" => name, "dependencies" => deps}

  describe "validate_no_cycles/1" do
    test "passes for a linear explicit chain" do
      definition = %{"blocks" => [block("A", []), block("B", ["A"]), block("C", ["B"])]}
      assert {:ok, ^definition} = Deps.validate_no_cycles(definition)
    end

    test "passes for a diamond / fan-in topology" do
      definition = %{
        "blocks" => [
          block("A", []),
          block("B", ["A"]),
          block("C", ["A"]),
          block("D", ["B", "C"])
        ]
      }

      assert {:ok, ^definition} = Deps.validate_no_cycles(definition)
    end

    test "passes when all dependencies are implicit (nil)" do
      definition = %{
        "blocks" => [
          %{"name" => "A"},
          %{"name" => "B"},
          %{"name" => "C"}
        ]
      }

      assert {:ok, ^definition} = Deps.validate_no_cycles(definition)
    end

    test "detects a simple two-block cycle" do
      definition = %{"blocks" => [block("A", ["B"]), block("B", ["A"])]}

      assert {:error, {:malformed, msg}} = Deps.validate_no_cycles(definition)
      assert msg =~ "Circular dependency between blocks detected:"
      assert msg =~ "\"A\""
      assert msg =~ "\"B\""
    end

    test "detects a longer cycle A -> B -> C -> A" do
      definition = %{
        "blocks" => [
          block("A", ["C"]),
          block("B", ["A"]),
          block("C", ["B"])
        ]
      }

      assert {:error, {:malformed, msg}} = Deps.validate_no_cycles(definition)
      assert msg =~ "Circular dependency between blocks detected:"
    end

    test "detects a self-dependency" do
      definition = %{"blocks" => [block("A", ["A"])]}

      assert {:error, {:malformed, msg}} = Deps.validate_no_cycles(definition)
      assert msg =~ "\"A\" → \"A\""
    end

    test "passes for a valid DAG that also has a separate acyclic branch" do
      definition = %{
        "blocks" => [
          block("A", []),
          block("B", ["A"]),
          block("C", ["B"]),
          block("D", []),
          block("E", ["B"])
        ]
      }

      assert {:ok, ^definition} = Deps.validate_no_cycles(definition)
    end
  end

  describe "validate_yaml/1 integration" do
    test "rejects a cyclic definition through the full validation chain" do
      definition = %{
        "blocks" => [
          block("A", ["B"]),
          block("B", ["A"])
        ]
      }

      assert {:error, {:malformed, msg}} = Deps.validate_yaml(definition)
      assert msg =~ "Circular dependency between blocks detected:"
    end
  end
end
