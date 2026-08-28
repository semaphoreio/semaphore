defmodule Ppl.Queues.Model.Queues.Test do
  use ExUnit.Case
  doctest Ppl.Queues.Model.Queues

  alias Ppl.Queues.Model.Queues

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  describe "safe_name/1" do
    test "returns names within the limit unchanged" do
      assert Queues.safe_name("master-.semaphore/semaphore.yml") ==
               "master-.semaphore/semaphore.yml"

      at_limit = String.duplicate("a", Queues.max_name_length())
      assert Queues.safe_name(at_limit) == at_limit
    end

    test "shortens an over-long name to fit the column and is deterministic" do
      name = String.duplicate("a", 300)
      safe = Queues.safe_name(name)

      assert codepoints(safe) == Queues.max_name_length()
      assert safe == Queues.safe_name(name)
      assert String.starts_with?(safe, String.duplicate("a", 100))
    end

    test "keeps distinct long names in distinct queues even when they share a prefix" do
      prefix = String.duplicate("feature/very-long-branch-", 12)
      name_a = prefix <> "a"
      name_b = prefix <> "b"

      assert codepoints(name_a) > Queues.max_name_length()
      refute Queues.safe_name(name_a) == Queues.safe_name(name_b)
    end

    test "counts multibyte names by codepoints, not bytes" do
      # 200 codepoints (600 bytes) fits varchar(255); 300 codepoints does not.
      kept = String.duplicate("中", 200)
      shortened = String.duplicate("中", 300)

      assert Queues.safe_name(kept) == kept
      assert codepoints(Queues.safe_name(shortened)) <= Queues.max_name_length()
    end
  end

  defp codepoints(str), do: str |> String.codepoints() |> length()
end
