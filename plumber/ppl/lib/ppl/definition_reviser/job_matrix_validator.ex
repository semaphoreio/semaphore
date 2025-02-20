defmodule Ppl.DefinitionReviser.JobMatrixValidator do
  @moduledoc """
  This module serves to validate that all job matrix values are provided
  as a list of strings either explicitly or after evaluation by SPC command line tool.
  """

  alias Util.ToTuple

  def validate(definition) do
    with {:ok, definition} <- do_validate_job_matrix_values(definition, "blocks"),
         {:ok, definition} <- do_validate_job_matrix_values(definition, "after_pipeline") do
      ToTuple.ok(definition)
    end
  end

  defp do_validate_job_matrix_values(definition, "blocks") do
    with {:ok, blocks} <- Map.fetch(definition, "blocks"),
         {:ok, _blocks} <- validate_job_matrix_values_in_blocks(blocks) do
      {:ok, definition}
    end
  end

  defp do_validate_job_matrix_values(definition, "after_pipeline") do
    Map.get(definition, "after_pipeline")
    |> case do
      nil ->
        {:ok, definition}

      _ ->
        with {:ok, blocks} <- Map.fetch(definition, "after_pipeline"),
             blocks <- Enum.map(blocks, &Map.put(&1, "name", "after_pipeline")),
             {:ok, _blocks} <- validate_job_matrix_values_in_blocks(blocks) do
          {:ok, definition}
        end
    end
  end

  defp validate_job_matrix_values_in_blocks(blocks) do
    Enum.reduce(blocks, {:ok, []}, &process_block(&1, &2))
  end

  defp process_block(block, {:ok, block_acc}) do
    jobs = get_in(block, ["build", "jobs"]) |> List.wrap()
    block_name = get_in(block, ["name"])

    case Enum.find_value(jobs, &validate_job_matrices(block_name, &1)) do
      nil -> {:ok, [block] ++ block_acc}
      {:error, error} -> {:error, error}
    end
  end

  defp process_block(_block, error), do: error

  defp validate_job_matrices(block_name, job) do
    matrix_values = Map.get(job, "matrix")
    job_name = Map.get(job, "name")

    if Map.has_key?(job, "matrix") and is_list(matrix_values) do
      Enum.find_value(matrix_values, &check_matrix_values(block_name, job_name, &1))
    end
  end

  defp check_matrix_values(block_name, job_name, matrix_entry) do
    env_var = get_in(matrix_entry, ["env_var"])
    values = get_in(matrix_entry, ["values"])

    if !is_list(values) || Enum.empty?(values) || !Enum.all?(values, &is_binary/1) do
      {:error, {:malformed, error_mesasge(block_name, job_name, env_var)}}
    end
  end

  defp error_mesasge(block_name, job_name, env_var) do
    "Matrix values for env_var '#{env_var}' (block '#{block_name}', job '#{job_name}' must be a non-empty list of strings."
  end
end
