defmodule Ppl.DefinitionReviser.TaskFileProperty do
  @moduledoc """
  Fetches content of the file specified by task_file property and
  replaces the property with the file content.
  """

  alias DefinitionValidator.{YamlMapValidator, YamlStringParser}
  alias Block.CodeRepo
  alias Util.ToTuple

  def fetch_and_merge(definition, ppl_req) do
    with {:ok, definition} <- do_fetch_and_merge(definition, ppl_req, "blocks"),
         {:ok, definition} <- do_fetch_and_merge(definition, ppl_req, "after_pipeline")
    do
      ToTuple.ok(definition)
    end
  end

  defp do_fetch_and_merge(definition, ppl_req, "blocks") do
    with {:ok, blocks} <- Map.fetch(definition, "blocks"),
         {:ok, blocks} <- fetch_and_merge_blocks(blocks, ppl_req),
         definition <- definition |> Map.put("blocks", blocks),
         do: YamlMapValidator.validate_yaml(definition)
  end

  defp do_fetch_and_merge(definition, ppl_req, "after_pipeline") do
    Map.get(definition, "after_pipeline")
    |> case do
      nil ->
        {:ok, definition}

      blocks ->
        with {:ok, blocks} <- fetch_and_merge_blocks([blocks], ppl_req),
             block <- Enum.at(blocks, 0),
             definition <- definition |> Map.put("after_pipeline", block),
             do: YamlMapValidator.validate_yaml(definition)
    end
  end

  defp fetch_and_merge_blocks(blocks, ppl_req) do
    updated_blocks = Enum.map(blocks, &fetch_and_merge_block(&1, ppl_req))

    updated_blocks
    |> Enum.find(:ok, fn {response, _} -> response != :ok end)
    |> case do
      :ok ->
        updated_blocks |> Enum.map(fn {:ok, block} -> block end) |> ToTuple.ok()

      error ->
        {:error, {:malformed, error}}
    end
  end

  defp fetch_and_merge_block(block = %{"task_file" => task_file}, ppl_req) do
    with {:ok, task_file_content} <- fetch_task_file(task_file, ppl_req),
         {:ok, task} <- YamlStringParser.parse(task_file_content),
         do: {:ok, merge_task(block, task)}
  end

  defp fetch_and_merge_block(block, _ppl_req), do: {:ok, block}

  defp fetch_task_file(task_file, %{request_args: request_args}),
    do: request_args |> Map.put("file_name", task_file) |> CodeRepo.get_file()

  defp merge_task(block, task),
    do: block |> Map.delete("task_file") |> Map.put("task", task)
end
