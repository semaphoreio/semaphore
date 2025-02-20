defmodule Zebra.Parallel do
  require Logger

  @doc """
  Processes elements of an array in batches.

  Example:

  Zebra.Parallel.in_batches([1, 2, 3], [batch_size: 2], fn element ->
    # ... magic ...
  end
  """
  def in_batches(list, [batch_size: batch_size], fun) do
    Enum.chunk_every(list, batch_size)
    |> Enum.reduce_while([], fn chunk, acc ->
      batch_res =
        Enum.map(chunk, fn element ->
          Task.async(fn ->
            fun.(element)
          end)
        end)
        |> Enum.map(fn t ->
          Task.await(t)
        end)

      if Enum.any?(batch_res, &halt?/1) do
        {:halt, acc ++ batch_res}
      else
        {:cont, acc ++ batch_res}
      end
    end)
  end

  defp halt?({:halt, _}), do: true
  defp halt?(_), do: false

  @doc """
  Processes elements concurrrently as a stream

  Options:
  - max_concurrency - maximum number of tasks run at the same time
                      defaults to batch_size
  - timeout - a timeout after which tasks is shut down
              defaults to 5_000
  - metadata - metadata to pass to the logger when tasks times out
  """
  def stream(list, opts \\ [], fun) do
    max_concurrency = Keyword.get(opts, :max_concurrency) || System.schedulers_online()
    timeout = Keyword.get(opts, :timeout) || 5_000
    metadata = Keyword.get(opts, :metadata) || []

    list
    |> Task.async_stream(fun,
      max_concurrency: max_concurrency,
      ordered: true,
      timeout: timeout,
      on_timeout: :kill_task
    )
    |> Stream.zip(list)
    |> Enum.into([], fn
      {{:exit, :timeout}, element} ->
        log_timeout(element, metadata)
        {element, {:error, :timeout}}

      {result, element} ->
        {element, result}
    end)
  end

  defp log_timeout(element, metadata) do
    metadata_string = "arg=#{inspect(element)} metadata=#{inspect(metadata)}"
    Logger.warn("Task timeout #{metadata_string}")
  end
end
