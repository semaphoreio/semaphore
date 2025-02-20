defmodule Ppl.Actions.DescribeTopologyImpl do
  @moduledoc """
  Module which implements DescribeTopology pipeline action
  """

  alias JobMatrix.Handler, as: JobMatrixHandler
  alias JobMatrix.ParallelismHandler, as: ParallelismHandler
  alias Util.ToTuple

  def describe_topology(definition) do
    with {:ok, blocks}         <- describe_blocks_topology(definition),
         {:ok, after_pipeline} <- describe_after_pipeline_topology(definition)
    do
      %{blocks: blocks, after_pipeline: after_pipeline}
      |> ToTuple.ok()
    else
      {:error, _} = error ->
        error

      _ ->
        %{blocks: [], after_pipeline: []}
        |> ToTuple.ok()
    end
  end

  defp describe_blocks_topology(nil), do: {:ok, []}
  defp describe_blocks_topology(ppl_request_definition) do
    blocks(ppl_request_definition["blocks"])
  end

  defp describe_after_pipeline_topology(%{"after_pipeline" => after_pipeline}) do
    jobs =
      after_pipeline
      |> Enum.at(0)
      |> Map.get("build", %{})
      |> Map.get("jobs", [])

    with {:ok, jobs} <- ParallelismHandler.handle_jobs(jobs),
         {:ok, jobs} <- JobMatrixHandler.handle_jobs(jobs),
         jobs <- Enum.map(jobs, &Map.get(&1, "name"))
    do
      {:ok, jobs}
    else
      error -> error
    end
    |> case do
      {:ok, jobs} ->
        ToTuple.ok(%{jobs: jobs})

      error -> error
    end
  end

  defp describe_after_pipeline_topology(_) do
    ToTuple.ok(%{jobs: []})
  end

  defp blocks(blocks) do
    blocks
    |> Enum.reduce_while({:ok, []}, fn block, {:ok, acc} ->
      with {:ok, jobs} <- jobs(block),
           block_name  <- Map.get(block, "name", ""),
           deps        <- block["dependencies"],
           topology    <- %{name: block_name, jobs: jobs, dependencies: deps}
      do
        {:cont, {:ok, acc ++ [topology]}}
      else
        error = {:error, _} -> {:halt, error}
        error -> {:halt, {:error, error}}
      end
    end)
  end

  defp jobs(block = %{"build" => build}) do
    with {:ok, n_jobs} <- normal_jobs(block),
         {:ok, b_jobs} <- booster_jobs(build["boosters"]),
         jobs          <- List.flatten(n_jobs, b_jobs),
    do: {:ok, jobs}
  end

  defp normal_jobs(block) do
    with {:ok, block} <- JobMatrixHandler.handle_block(block),
         jobs         <- block |> Map.get("build", %{}) |> Map.get("jobs", []),
         job_names    <-  Enum.map(jobs, fn job -> Map.get(job, "name", "") end),
    do:  {:ok, job_names}
  end

  # Booster job extraction
  defp booster_jobs(nil), do: {:ok, []}
  defp booster_jobs(boosters) do
    Enum.map(boosters, &create_booster_jobs/1) |> List.flatten |> ToTuple.ok()
  end

  defp create_booster_jobs(booster) do
    for index <- 1..booster["job_count"] do
      booster_job_name(booster, index)
    end
  end

  defp booster_job_name(booster, index),
    do: "#{Map.get(booster, "name", "")} #{Map.get(booster, "type", "")}#{index}"
end
