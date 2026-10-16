defmodule Zebra.Workers.JobRequestFactory.FailureReasonTest do
  use ExUnit.Case, async: true

  alias Zebra.Workers.JobRequestFactory.FailureReason

  defp codepoints(text), do: text |> String.codepoints() |> length()

  describe "clip/1" do
    test "keeps short names unchanged" do
      assert FailureReason.clip("deploy-creds") == "deploy-creds"
    end

    test "keeps at most 40 codepoints" do
      assert FailureReason.clip(String.duplicate("a", 100)) == String.duplicate("a", 40)
      assert codepoints(FailureReason.clip("x" <> String.duplicate("́", 300))) == 40
    end

    test "replaces control characters" do
      assert FailureReason.clip("a\nb\rc\td") == "a?b?c?d"
    end

    test "drops invalid UTF-8" do
      assert FailureReason.clip(<<"bad", 0xFF, 0xFE, "name">>) == "badname"
    end
  end

  describe "join/2" do
    test "joins entries after the prefix" do
      assert FailureReason.join(["a", "b"], "Problems: ") == "Problems: a, b"
      assert FailureReason.join(["a", "b"]) == "a, b"
    end

    test "returns the prefix when there are no entries" do
      assert FailureReason.join([], "Problems: ") == "Problems: "
    end

    test "keeps as many entries as fit and counts the rest" do
      entries = Enum.map(1..30, &"Secret secret-number-#{&1} not found")

      reason = FailureReason.join(entries)

      assert codepoints(reason) <= 255
      assert reason =~ ~r/^Secret secret-number-1 not found, /
      assert reason =~ ~r/ and \d+ more$/
    end

    test "uses the full 255 codepoints before dropping an entry" do
      long = String.duplicate("e", 240)

      assert FailureReason.join([long, String.duplicate("y", 10)], "P: ") ==
               "P: " <> long <> ", " <> String.duplicate("y", 10)

      assert FailureReason.join([long, String.duplicate("y", 11)], "P: ") ==
               "P: " <> long <> " and 1 more"
    end

    test "truncates when not even one entry fits after the prefix" do
      prefix = String.duplicate("p", 300)

      assert FailureReason.join(["a", "b"], prefix) == String.duplicate("p", 255)
    end

    test "truncates a single oversized entry after the prefix" do
      reason = FailureReason.join([String.duplicate("e", 300)], "P: ")

      assert reason == "P: " <> String.duplicate("e", 252)
    end

    test "fits entries made of multi-codepoint graphemes" do
      entry = "x" <> String.duplicate("́", 300)

      reason = FailureReason.join([entry, entry], "Problems: ")

      assert String.valid?(reason)
      assert codepoints(reason) <= 255
    end
  end
end
