defmodule Zebra.ParallelTest do
  use ExUnit.Case

  describe ".in_batches" do
    test "it processes all entries" do
      res =
        [1, 2, 3]
        |> Zebra.Parallel.in_batches([batch_size: 2], fn el ->
          el + 1
        end)

      assert res == [2, 3, 4]
    end

    test "it halts" do
      res =
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        |> Zebra.Parallel.in_batches([batch_size: 2], fn el ->
          if el == 4, do: {:halt, el + 1}, else: el + 1
        end)

      assert res == [2, 3, 4, {:halt, 5}]
    end
  end

  describe "stream/3" do
    test "it processes all entries" do
      res =
        [1, 2, 3]
        |> Zebra.Parallel.stream([max_concurrency: 2], fn el ->
          el + 1
        end)

      assert res == [{1, {:ok, 2}}, {2, {:ok, 3}}, {3, {:ok, 4}}]
    end

    test "handles timeouts gracefully" do
      res =
        1..10
        |> Zebra.Parallel.stream(
          [max_concurrency: 2, timeout: 500, metadata: [foo: :bar]],
          fn el ->
            Process.sleep(el * 100)
            el + 1
          end
        )

      assert res
             |> Enum.filter(&(elem(&1, 0) < 5))
             |> Enum.all?(&match?({_, {:ok, _}}, &1))

      assert res
             |> Enum.filter(&(elem(&1, 0) >= 5))
             |> Enum.all?(&match?({_, {:error, :timeout}}, &1))
    end

    test "handles custom timeout" do
      res =
        1..10
        |> Zebra.Parallel.stream([max_concurrency: 2, timeout: 50], fn el ->
          Process.sleep(el * 100)
          el + 1
        end)

      assert Enum.all?(res, &match?({_, {:error, :timeout}}, &1))
    end

    test "handles passing metadata to logger" do
      res =
        1..10
        |> Zebra.Parallel.stream([max_concurrency: 2, metadata: [foo: :bar]], fn el ->
          el + 1
        end)

      assert Enum.all?(res, &match?({_, {:ok, _}}, &1))
    end
  end
end
