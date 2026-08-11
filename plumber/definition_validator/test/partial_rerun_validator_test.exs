defmodule DefinitionValidator.PartialRerunValidator.Test do
  use ExUnit.Case
  doctest DefinitionValidator.PartialRerunValidator

  alias DefinitionValidator.PartialRerunValidator

  defp definition(extra \\ %{}, block_extra \\ %{}) do
    block = Map.merge(%{"name" => "Unit tests", "task" => %{"jobs" => []}}, block_extra)

    Map.merge(%{"version" => "v1.0", "blocks" => [block]}, extra)
  end

  test "definition without the property is valid" do
    ppl = definition()
    assert PartialRerunValidator.validate_yaml(ppl) == {:ok, ppl}
  end

  test "valid values are accepted on both levels" do
    for value <- ["jobs", "block"] do
      ppl = definition(%{"partial_rerun" => value}, %{"partial_rerun" => value})
      assert PartialRerunValidator.validate_yaml(ppl) == {:ok, ppl}
    end
  end

  test "unknown pipeline level value is rejected" do
    ppl = definition(%{"partial_rerun" => "blcok"})

    {:error, {:malformed, message}} = PartialRerunValidator.validate_yaml(ppl)

    assert message =~ "'partial_rerun' property on pipeline level is not valid"
    assert message =~ "blcok"
    assert message =~ "jobs, block"
  end

  test "unknown block level value is rejected and names the block" do
    ppl = definition(%{}, %{"partial_rerun" => "all"})

    {:error, {:malformed, message}} = PartialRerunValidator.validate_yaml(ppl)

    assert message =~ "block 'Unit tests' level is not valid"
    assert message =~ "all"
  end

  test "an unnamed block still reports a useful error" do
    ppl = %{
      "version" => "v1.0",
      "blocks" => [%{"task" => %{"jobs" => []}, "partial_rerun" => "nope"}]
    }

    {:error, {:malformed, message}} = PartialRerunValidator.validate_yaml(ppl)

    assert message =~ "on block level is not valid"
  end

  test "non string values are rejected" do
    ppl = definition(%{"partial_rerun" => true})

    {:error, {:malformed, message}} = PartialRerunValidator.validate_yaml(ppl)

    assert message =~ "is not valid"
  end

  test "a definition without blocks is valid" do
    ppl = %{"version" => "v1.0", "partial_rerun" => "jobs"}
    assert PartialRerunValidator.validate_yaml(ppl) == {:ok, ppl}
  end

  test "non map input passes through" do
    assert PartialRerunValidator.validate_yaml("") == {:ok, ""}
  end
end
