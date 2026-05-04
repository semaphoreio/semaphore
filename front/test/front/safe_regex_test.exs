defmodule Front.SafeRegexTest do
  use ExUnit.Case, async: true

  alias Front.SafeRegex

  describe "match/2" do
    test "returns {:ok, true} on match" do
      assert {:ok, true} = SafeRegex.match("^[0-9]+$", "123")
    end

    test "returns {:ok, false} on no match" do
      assert {:ok, false} = SafeRegex.match("^[0-9]+$", "abc")
    end

    test "rejects pattern over the length cap" do
      pattern = String.duplicate("a", SafeRegex.max_pattern_length() + 1)
      assert {:error, :pattern_too_long} = SafeRegex.match(pattern, "anything")
    end

    test "rejects value over the length cap" do
      value = String.duplicate("a", SafeRegex.max_value_length() + 1)
      assert {:error, :value_too_long} = SafeRegex.match("^a+$", value)
    end

    test "rejects malformed pattern" do
      assert {:error, :invalid_pattern} = SafeRegex.match("[", "anything")
    end

    test "bounded execution of an adversarial pattern terminates quickly" do
      # Classic ReDoS shape: nested quantifiers + tail that forces backtracking.
      pattern = "^([a-zA-Z]+)*$"
      value = String.duplicate("a", 50) <> "1"

      {elapsed_us, result} = :timer.tc(fn -> SafeRegex.match(pattern, value) end)

      # Whether match_limit catches this depends on the PCRE build, but
      # the wall-clock guard must keep it well under the 100ms bound
      # plus a small CI-jitter margin.
      assert elapsed_us < 500_000

      case result do
        {:ok, false} -> :ok
        {:error, reason} -> assert reason in [:match_limit_exceeded, :timeout]
        other -> flunk("unexpected result: #{inspect(other)}")
      end
    end

    test "treats nil value as no match" do
      assert {:ok, false} = SafeRegex.match("^a+$", nil)
    end

    test "treats nil pattern as invalid" do
      assert {:error, :invalid_pattern} = SafeRegex.match(nil, "anything")
    end
  end
end
