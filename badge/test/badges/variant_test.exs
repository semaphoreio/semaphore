defmodule Badges.VariantTest do
  use ExUnit.Case

  alias Badges.Models.Pipeline
  alias Badges.Variant

  describe ".calculate" do
    test "state is WAITING => returns :pending" do
      pipeline = %Pipeline{state: :WAITING}

      assert Variant.calculate(pipeline) == :pending
    end

    test "state is RUNNING => returns :pending" do
      pipeline = %Pipeline{state: :RUNNING}

      assert Variant.calculate(pipeline) == :pending
    end

    test "state is STOPPING => returns :pending" do
      pipeline = %Pipeline{state: :STOPPING}

      assert Variant.calculate(pipeline) == :pending
    end

    test "state is INITIALIZING => returns :pending" do
      pipeline = %Pipeline{state: :INITIALIZING}

      assert Variant.calculate(pipeline) == :pending
    end

    test "state is DONE and result is STOPPED => returns :stopped" do
      pipeline = %Pipeline{state: :DONE, result: :STOPPED}

      assert Variant.calculate(pipeline) == :stopped
    end

    test "state is DONE and result is CANCELED => returns :canceled" do
      pipeline = %Pipeline{state: :DONE, result: :CANCELED}

      assert Variant.calculate(pipeline) == :canceled
    end

    test "state is DONE and result is PASSED => returns :passed" do
      pipeline = %Pipeline{state: :DONE, result: :PASSED}

      assert Variant.calculate(pipeline) == :passed
    end

    test "state is DONE and result is FAILED => returns :failed" do
      pipeline = %Pipeline{state: :DONE, result: :FAILED}

      assert Variant.calculate(pipeline) == :failed
    end
  end
end
