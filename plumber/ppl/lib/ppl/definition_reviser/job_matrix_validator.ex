defmodule Ppl.DefinitionReviser.JobMatrixValidator do
  @moduledoc """
  This module serves to validate that all job matrix values are provided
  as a list of strings either explicitly or after evaluation by SPC command line tool.

  It also validates that there are no duplicate environment variable names in the job matrix.
  It also validates that the total product size of the matrix (product of number of values of each environment variable) is not too large.
  """

  alias Util.ToTuple

  @max_size 100

  def validate(definition) do
    with {:ok, definition} <- do_validate_job_matrix_values(definition, "blocks"),
         {:ok, definition} <- do_validate_job_matrix_values(definition, "after_pipeline") do
      ToTuple.ok(definition)
    else
      {:error, _} = error -> error
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

    # Calculate total matrix size across all jobs in the block
    total_result =
      Enum.reduce_while(jobs, {:ok, 0}, fn job, {:ok, total_size} ->
        case validate_job_matrices(block_name, job) do
          nil -> {:cont, {:ok, total_size}}
          {:ok, matrix_size} -> {:cont, {:ok, total_size + matrix_size}}
          {:error, _} = error -> {:halt, error}
        end
      end)

    case total_result do
      {:ok, total_size} ->
        if total_size > @max_size do
          {:error,
           {:malformed,
            "Total matrix size exceeds maximum allowed size (#{@max_size}) in block '#{block_name}'. " <>
              "The matrix product size is calculated as the product of the number of values for each environment variable."}}
        else
          {:ok, [block] ++ block_acc}
        end

      {:error, _} = error ->
        error
    end
  end

  defp process_block(_block, error), do: error

  defp validate_job_matrices(block_name, job) do
    matrix_values = Map.get(job, "matrix")
    job_name = Map.get(job, "name")

    if Map.has_key?(job, "matrix") and is_list(matrix_values) do
      case validate_job_matrix(block_name, job_name, matrix_values, job) do
        {:ok, matrix_size} -> {:ok, matrix_size}
        {:error, _} = error -> error
        nil -> nil
      end
    end
  end

  defp validate_job_matrix(block_name, job_name, matrix_values, job) do
    with nil <- check_for_duplicate_env_vars(block_name, job_name, matrix_values),
         nil <- Enum.find_value(matrix_values, &check_matrix_values(block_name, job_name, &1)),
         {:ok, matrix_size} <- check_matrix_product_size(block_name, job_name, matrix_values, job) do
      {:ok, matrix_size}
    else
      {:error, _} = error -> error
    end
  end

  defp check_for_duplicate_env_vars(block_name, job_name, matrix_values) do
    env_var_names_count =
      Enum.reduce(matrix_values, %{}, fn matrix_entry, acc ->
        env_var = Map.get(matrix_entry, "env_var")
        Map.update(acc, env_var, 1, &(&1 + 1))
      end)

    Enum.find_value(env_var_names_count, fn {env_var_name, count} ->
      if count > 1 do
        {:error,
         {:malformed, duplicate_env_var_error_message(block_name, job_name, env_var_name)}}
      end
    end)
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

  defp duplicate_env_var_error_message(block_name, job_name, env_var_name) do
    "Duplicate environment variable(s): '#{env_var_name}' in job matrix (block '#{block_name}', job '#{job_name}')."
  end

  def check_matrix_product_size(block_name, job_name, matrix_values, _job) do
    matrix_size =
      Enum.reduce(matrix_values, 1, fn matrix_entry, acc ->
        values = get_in(matrix_entry, ["values"])
        if is_list(values), do: min(acc * length(values), @max_size + 1), else: acc
      end)

    if matrix_size > @max_size do
      {:error,
       {:malformed,
        matrix_product_size_error_message(block_name, job_name, matrix_size, @max_size)}}
    else
      {:ok, matrix_size}
    end
  end

  defp matrix_product_size_error_message(block_name, job_name, size, max_size) do
    "Matrix product size exceeds maximum allowed size (#{max_size}) in job matrix (block '#{block_name}', job '#{job_name}'). " <>
      "The matrix product size is calculated as the product of the number of values for each environment variable."
  end
end
