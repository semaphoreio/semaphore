defmodule PublicAPI.Util.Metrics do
  @moduledoc """
  Utility functions for sending metrics

  Send metric while executing function:
  - increment count (of type counter) by 1 when entering the function
  - increment count (of type timer) by 1 when exiting the function
  - function latency
  """
  def benchmark(name, tags, f) when is_atom(name),
    do: name |> inspect |> benchmark(tags, f)

  def benchmark(name, tags, f)
      when is_binary(name) and is_list(tags) and is_function(f, 0),
      do: {name, tags} |> benchmark(f)

  def benchmark(metric_name, f) when is_function(f, 0) do
    Watchman.benchmark(metric_name, fn ->
      Watchman.increment(metric_name)

      f.()
    end)
  end
end
