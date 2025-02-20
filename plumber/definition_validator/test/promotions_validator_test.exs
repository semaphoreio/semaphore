defmodule DefinitionValidator.PromotionsValidator.Test do
  use ExUnit.Case
  doctest DefinitionValidator.PromotionsValidator

  alias DefinitionValidator.PromotionsValidator

  test "valid" do
    task = %{"jobs" => [%{"commands" => ["echo foo"]}]}
    blocks = [%{"task" => task}]
    agent = %{"machine" => %{"type" => "foo", "os_image" => "bar"}}
    ppl = %{"version" => "v1.0", "blocks" => blocks, "agent" => agent}
    assert PromotionsValidator.validate_yaml(ppl) == {:ok, ppl}
  end

  test "empty map" do
    {:ok, %{}} = PromotionsValidator.validate_yaml(%{})
  end

  test "empty string" do
    {:error, {:malformed, "Empty string is not a valid YAML"}} = PromotionsValidator.validate_yaml("")
  end

  describe "when SKIP_PROMOTIONS flag is set to true" do
    setup do
      System.put_env("SKIP_PROMOTIONS", "true")
      on_exit(fn -> System.delete_env("SKIP_PROMOTIONS") end)
    end

    test "rejects when promotions present" do
      definition = %{"promotions" => [%{"name" => "prod"}]}
      assert {:error, {:malformed, message}} =
        PromotionsValidator.validate_yaml(definition)
      assert message == "Promotions are not available in the Comunity edition of Semaphore."
    end

    test "accepts when no promotions" do
      definition = %{"blocks" => []}
      assert {:ok, _} = PromotionsValidator.validate_yaml(definition)
    end
  end
end
