defmodule JobMatrix.ParallelismHandler do
  @moduledoc """
  Converts parallelism field inside jobs into build matrix
  """

  alias Util.ToTuple

  def parallelize_jobs(block_def) when is_map(block_def)  do
    with {:ok, build} <- fetch_entity(block_def, "build"),
         {:ok, jobs}  <- fetch_jobs(build),
         {:ok, jobs}  <- handle_jobs(jobs),
         block_def    <- put_in(block_def, ["build", "jobs"], jobs)
    do
      {:ok, block_def}
    end
  end
  def parallelize_jobs(_block_def),
    do: {:error, {:malformed, "'block' must be of type Map."}}

  defp fetch_entity(map, field_name) when is_map(map) do
    case Map.fetch(map, field_name) do
      res = {:ok, _} -> res
      :error -> {:error, {:malformed, "Missing #{inspect field_name} field."}}
    end
  end
  defp fetch_entity(map, _), do: {:error, {:malformed, "#{inspect map} is not a Map."}}

  defp fetch_jobs(build) when is_map(build), do: {:ok, Map.get(build, "jobs", nil)}
  defp fetch_jobs(build), do: {:error, {:malformed, "#{inspect build} is not a Map."}}

  def handle_jobs(jobs) when is_list(jobs) and jobs != [] do
    {:ok, jobs |> Enum.map(fn(job) -> parallelize_job(job) end)}
  end
  def handle_jobs([]), do: {:ok, []}
  def handle_jobs(_), do: {:error, {:malformed, "'jobs' must be of type List."}}

  defp parallelize_job(job) do
    with count      <- Map.get(job, "parallelism", 0),
         {:ok, job} <- create_matrix(job, count),
         {:ok, job} <- add_count_env_var(job, count)
    do
      job |> Map.delete("parallelism")
    end
  end

  defp create_matrix(job, 0), do: {:ok, job}
  defp create_matrix(job, count) do
    job
    |> Map.put(
      "matrix",
      [%{"env_var" => "SEMAPHORE_JOB_INDEX", "values" => count_up_to(count)}]
    )
    |> ToTuple.ok()
  end

  defp count_up_to(count) do
    1..count |> Enum.map(fn num -> "#{num}" end)
  end

  defp add_count_env_var(job, 0), do: {:ok, job}
  defp add_count_env_var(job, count) do
    env_vars =
      Map.get(job, "env_vars", []) ++
      [%{"name" => "SEMAPHORE_JOB_COUNT", "value" => "#{count}"}]

    job |> Map.put("env_vars", env_vars) |> ToTuple.ok()
  end
end
