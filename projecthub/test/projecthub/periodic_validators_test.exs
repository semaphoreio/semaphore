defmodule Projecthub.PeriodicValidatorsTest do
  use ExUnit.Case, async: true

  alias Projecthub.PeriodicValidators

  describe "validate_all/2" do
    test "returns :ok for an empty list" do
      assert :ok = PeriodicValidators.validate_all([], [&PeriodicValidators.validate_cron/1])
    end

    test "returns :ok when all items pass all validators" do
      items = [
        %{at: "* * * * *", name: "a"},
        %{at: "0 0 * * *", name: "b"}
      ]

      assert :ok = PeriodicValidators.validate_all(items, [&PeriodicValidators.validate_cron/1])
    end

    test "returns the first error and halts before reaching later items" do
      raising_validator = fn _ -> raise "should not be called for items after the first failure" end

      items = [
        %{at: "garbage", name: "bad"},
        %{at: "* * * * *", name: "later"}
      ]

      assert {:error, "Invalid cron expression in task 'bad': " <> _} =
               PeriodicValidators.validate_all(items, [
                 &PeriodicValidators.validate_cron/1,
                 raising_validator
               ])
    end

    test "halts at the first failing validator within a single item" do
      raising_validator = fn _ -> raise "should not be called after the cron validator fails" end

      items = [%{at: "garbage", name: "bad"}]

      assert {:error, _} =
               PeriodicValidators.validate_all(items, [
                 &PeriodicValidators.validate_cron/1,
                 raising_validator
               ])
    end
  end

  describe "validate_cron/1" do
    test "returns :ok for a valid cron expression" do
      assert :ok = PeriodicValidators.validate_cron(%{at: "* * * * *", name: "n"})
    end

    test "returns error tuple for an invalid cron expression" do
      assert {:error, "Invalid cron expression in task 'n': " <> _} =
               PeriodicValidators.validate_cron(%{at: "garbage", name: "n"})
    end

    test "returns :ok when recurring is explicitly false (skips parsing)" do
      assert :ok =
               PeriodicValidators.validate_cron(%{recurring: false, at: "garbage", name: "n"})
    end

    test "validates when recurring is true" do
      assert :ok = PeriodicValidators.validate_cron(%{recurring: true, at: "*", name: "n"})

      assert {:error, _} =
               PeriodicValidators.validate_cron(%{recurring: true, at: "garbage", name: "n"})
    end
  end
end
