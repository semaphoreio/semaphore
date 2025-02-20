defmodule Ppl.DefinitionReviser.Task2Build do
  @moduledoc """
  Renames 'task' property from ppl definition => 'build' key used in the code
  """

  alias Util.ToTuple

  @doc """
    Example:

      iex> rename(%{"blocks" => [%{"task" => []}]})
      {:ok, %{"blocks" => [%{"build" => []}]}}

      iex> rename(%{"blocks" => [%{"task" => []}], "after_pipeline" => %{"task" => []}})
      {:ok, %{"after_pipeline" => [%{"build" => []}], "blocks" => [%{"build" => []}]}}
  """
  def rename(definition) do
    with {:ok, definition} <- do_rename(definition, "blocks"),
         {:ok, definition} <- do_rename(definition, "after_pipeline")
    do
      ToTuple.ok(definition)
    end
  end

  def do_rename(definition, "blocks"),
    do: {:ok, Map.put(definition, "blocks", rename_blocks(definition["blocks"]))}

  def do_rename(definition, "after_pipeline") do
    Map.get(definition, "after_pipeline")
    |> case do
      nil -> {:ok, definition}
      _ -> {:ok, Map.put(definition, "after_pipeline", rename_blocks([definition["after_pipeline"]]))}
    end
  end

  def rename_blocks(blocks) do
    for block <- blocks,
        do: block |> Map.get("task") |> replace_task(block)
  end

  def replace_task(nil, block), do: block

  def replace_task(task, block),
    do: block |> Map.put("build", task) |> Map.delete("task")
end
