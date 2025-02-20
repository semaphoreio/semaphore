defmodule Ppl.DefinitionReviser.MaxTimeLimitChecker do
  @moduledoc """
  Module checks all execution_time_limits for pipelne, blocks and jobs and returns
  error if there are any irregularities.
  """

  alias Util.ToTuple


  @max_job_time_mins 24 * 60


  def check_exec_time_limits(definition) do

    {longest_block, block_path} = {0, "#/blocks/0"}
    {longest_job, job_path} = {0, "#/blocks/0/task/jobs/0"}

    params = {:ok, [longest_block, block_path, longest_job, job_path]}

    case validate_blocks_limits(definition, params) do
      {:ok, results} -> validate_ppl_limit(definition, results)

      error -> error
    end
  end

  defp validate_ppl_limit(definition, [longest_block, block_path,
                                       longest_job, job_path]) do
    ppl_limit = get_limit(definition, 60)

    cond do
      ppl_limit < longest_block ->
        block_longer_than_ppl_error(ppl_limit, longest_block, block_path)

      ppl_limit < longest_job ->
        job_longer_than_ppl_error(ppl_limit, longest_job, job_path)

      ppl_limit > @max_job_time_mins and longest_job < @max_job_time_mins ->
        ppl_limit_over_max_job_time_error(ppl_limit)

      true ->
        {:ok, definition}
    end
  end

  defp validate_blocks_limits(definition, params) do
    definition
    |> Map.get("blocks")
    |> Enum.with_index()
    |> Enum.reduce_while(params, fn {block_def, index}, {:ok, acc} ->
      with block_limit <- get_limit(block_def),
           block_path  <- "#/blocks/#{index}",
           job_details <- get_max_job_details(block_def, block_path)
      do
        validate_block_limit(block_limit, block_path, job_details, acc)
      end
    end)
  end

  defp validate_block_limit(block_limit, block_path, {max_job, j_path}, acc) do
    cond do
      block_limit > @max_job_time_mins and max_job < @max_job_time_mins ->
        {:halt, block_limit_over_max_job_error(block_limit, block_path)}

      block_limit > 0 and block_limit < max_job ->
        {:halt, job_longer_than_block_error(block_limit, max_job, j_path)}

      block_limit > Enum.at(acc, 0) and max_job > Enum.at(acc, 2) ->
        {:cont, {:ok, [block_limit, block_path, max_job, j_path]}}

      block_limit > Enum.at(acc, 0) ->
        {:cont, {:ok, [block_limit, block_path] ++ Enum.slice(acc, 2..3)}}

      max_job > Enum.at(acc, 2) ->
        {:cont, {:ok, Enum.slice(acc, 0..1) ++ [max_job, j_path]}}

      true ->
        {:cont, {:ok, acc}}
    end
  end

  defp get_limit(map, default \\ 0) do
    map |> Map.get("execution_time_limit") |> to_minutes(default)
  end

  defp to_minutes(nil, default), do: default
  defp to_minutes(limit_map, _default) do
    Map.get(limit_map, "minutes", 0) + Map.get(limit_map, "hours", 0) * 60
  end

  defp get_max_job_details(%{"task" => %{"jobs" => jobs}}, block_path) do
    path = block_path <> "task/jobs/0"
    jobs
    |> Enum.with_index()
    |> Enum.reduce({0, path}, fn {job, index}, acc = {max_job, _} ->
      job_limit = get_limit(job)
      if job_limit > max_job do
        {job_limit, block_path <> "/task/jobs/#{index}"}
      else
        acc
      end
    end)
  end

  defp block_longer_than_ppl_error(ppl_limit, block_limit, block_path) do
    "Block on path '#{block_path}' has an execution_time_limit of #{format(block_limit)}"
    <> " which is longer than execution_time_limit of a whole pipeline which is"
    <> " #{format(ppl_limit)}. This would cause that block to stop when pipeline"
    <> " level time limit is reached."
    |> ToTuple.error(:malformed)
  end
  defp job_longer_than_ppl_error(ppl_limit, job_limit, job_path) do
    "Job on path '#{job_path}' has an execution_time_limit of #{format(job_limit)}"
    <> " which is longer than execution_time_limit of a whole pipeline which is"
    <> " #{format(ppl_limit)}. This would cause that job to stop when pipeline"
    <> " level time limit is reached."
    |> ToTuple.error(:malformed)
  end
  defp ppl_limit_over_max_job_time_error(ppl_limit) do
    "The pipeline level execution_time_limit is set to #{format(ppl_limit)}"
    <> " which is longer than default job level execution_time_limit of"
    <> " #{format(@max_job_time_mins)}. This would cause the pipeline to stop as"
    <> " soon as first job reaches that default time limit for jobs."
    |> ToTuple.error(:malformed)
  end

  defp block_limit_over_max_job_error(block_limit, block_path) do
    "The execution_time_limit of a block on path '#{block_path}' is set to"
    <> " #{format(block_limit)} which is longer than default job level"
    <> " execution_time_limit of #{format(@max_job_time_mins)}. This would cause"
    <> " the block to stop as soon as first job reaches that default time limit"
    <> " for jobs."
    |> ToTuple.error(:malformed)
  end
  defp job_longer_than_block_error(block_limit, job_limit, job_path) do
    "Job on path '#{job_path}' has an execution_time_limit of #{format(job_limit)}"
    <> " which is longer than #{format(block_limit)} that is the execution_time_limit"
    <> " of a block to which this job belongs. This would cause that job to stop"
    <> " when block level time limit is reached."
    |> ToTuple.error(:malformed)
  end

  defp format(duration) do
    hours = div(duration, 60)
    minutes = rem(duration, 60)
    to_str(hours, minutes)
  end

  defp to_str(0, 1), do: "1 minute"
  defp to_str(0, minutes), do: "#{minutes} minutes"
  defp to_str(1, 0), do: "1 hour"
  defp to_str(hours, 0), do: "#{hours} hours"
  defp to_str(hours, minutes), do: "#{hours} hours and #{minutes} minutes"
end
