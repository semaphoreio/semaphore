defmodule Ppl.DefinitionReviser.ParallelismValidator do
  @moduledoc """
  This module serves to validate that all parallelism values are integers
  either explicitly or after evaluation by SPC command line tool.
  """

  alias Util.ToTuple

  def validate(definition) do
    with {:ok, definition} <- do_validate_parallelism(definition, "blocks"),
         {:ok, definition} <- do_validate_parallelism(definition, "after_pipeline") do
      ToTuple.ok(definition)
    end
  end

  defp do_validate_parallelism(definition, "blocks") do
    with {:ok, blocks} <- Map.fetch(definition, "blocks"),
         {:ok, _blocks} <- revise_parallelisms_in_blocks(blocks) do
      {:ok, definition}
    end
  end

  defp do_validate_parallelism(definition, "after_pipeline") do
    Map.get(definition, "after_pipeline")
    |> case do
      nil ->
        {:ok, definition}

      _ ->
        with {:ok, blocks} <- Map.fetch(definition, "after_pipeline"),
             blocks <- blocks |> Enum.map(&Map.put(&1, "name", "after_pipeline")),
             {:ok, _blocks} <- revise_parallelisms_in_blocks(blocks) do
          {:ok, definition}
        end
    end
  end

  defp revise_parallelisms_in_blocks(blocks) do
    Enum.reduce(blocks, {:ok, []}, &process_block(&1, &2))
  end

  defp process_block(block, block_acc) do
    jobs = get_in(block, ["build", "jobs"]) |> List.wrap()
    block_name = get_in(block, ["name"])

    case Enum.find_value(jobs, &validate_job_parallelism(block_name, &1)) do
      nil -> {:ok, [block] ++ block_acc}
      {:error, error} -> {:error, error}
    end
  end

  defp validate_job_parallelism(block_name, job) do
    job_name = Map.get(job, "name")

    if Map.has_key?(job, "parallelism") && !is_integer(Map.get(job, "parallelism")),
      do:
        {:error,
         {:malformed,
          "Parallelism value for job '#{job_name}' in block '#{block_name}' is not an integer."}}
  end
end
