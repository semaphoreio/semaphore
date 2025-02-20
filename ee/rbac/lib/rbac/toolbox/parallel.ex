defmodule Rbac.Toolbox.Parallel do
  def in_batches(list, [batch_size: batch_size], fun) do
    Enum.chunk_every(list, batch_size)
    |> Enum.reduce([], fn chunk, acc ->
      batch_res =
        Enum.map(chunk, fn element ->
          Task.async(fn ->
            fun.(element)
          end)
        end)
        |> Enum.map(fn t ->
          Task.await(t, :infinity)
        end)

      acc ++ batch_res
    end)
  end
end
