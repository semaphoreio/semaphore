defmodule JobMatrix.Handler do
  @moduledoc """
  Module that creates multiple Jobs from Block -> Build -> Jobs definitions
  based on the 'matrix' or 'parallelism' parameters.

  Module should create a new Job for all combinations from the Matrix.
  """

  alias JobMatrix.Validator
  alias JobMatrix.Transformer
  alias JobMatrix.ParallelismHandler

  @doc ~S"""
  ##Example
      iex> JobMatrix.Handler.handle_block(
      ...> %{"build" => %{"jobs" => [
      ...>     %{"commands" => ["echo job1"], "name" => "matrix job 1",
      ...>       "matrix" => [
      ...>           %{"env_var" => "ERLANG", "values" => ["18", "19"]},
      ...>           %{"env_var" => "PYTHON", "values" => ["2.7", "3.4"]}]}],
      ...>       "name" => "build matrix",
      ...>       "agent" => %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}},
      ...>       "version" => "v1.0"}})
      {:ok,
            %{"build" => %{"jobs" => [
                 %{"commands" => ["echo job1"],
                   "env_vars" => [%{name: "ERLANG", value: "18"},
                    %{name: "PYTHON", value: "2.7"}],
                   "name" => "matrix job 1 - ERLANG=18, PYTHON=2.7"},
                 %{"commands" => ["echo job1"],
                   "env_vars" => [%{name: "ERLANG", value: "18"},
                    %{name: "PYTHON", value: "3.4"}],
                   "name" => "matrix job 1 - ERLANG=18, PYTHON=3.4"},
                 %{"commands" => ["echo job1"],
                   "env_vars" => [%{name: "ERLANG", value: "19"},
                    %{name: "PYTHON", value: "2.7"}],
                   "name" => "matrix job 1 - ERLANG=19, PYTHON=2.7"},
                 %{"commands" => ["echo job1"],
                   "env_vars" => [%{name: "ERLANG", value: "19"},
                    %{name: "PYTHON", value: "3.4"}],
                   "name" => "matrix job 1 - ERLANG=19, PYTHON=3.4"}],
                "name" => "build matrix",
                "agent" => %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}},
                "version" => "v1.0"}}}
  """
  def handle_block(block) when is_map(block) do
    with {:ok, block} <- ParallelismHandler.parallelize_jobs(block),
         {:ok, build} <- fetch_entity(block, "build"),
         {:ok, jobs}  <- fetch_jobs(build),
         {:ok, jobs}  <- handle_jobs(jobs),
         block        <- put_in(block, ["build", "jobs"], jobs)
    do
      {:ok, block}
    end
  end
  def handle_block(_), do: {:error, {:malformed, "'block' must be of type Map."}}

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
    {:ok,
      jobs
      |> Enum.map(fn(job) -> transform_job(job) end)
      |> List.flatten()
    }
  catch
    error -> error
  end
  def handle_jobs(nil), do: {:ok, []}
  def handle_jobs([]), do: {:ok, []}
  def handle_jobs(_), do: {:error, {:malformed, "'jobs' must be of type List."}}

  # Transforms Matrix into EnvVars List.
  # Transforms a Job and an EnvVars List into a List of Jobs.
  defp transform_job(job) do
    with matrix <- Map.get(job, "matrix"),
         {:ok, _} <- Validator.validate(matrix),
         {:ok, env_vars_list} <- Transformer.to_env_vars_list(matrix)
    do
      job |> Map.delete("matrix") |> create_jobs(env_vars_list)
    else
      error -> throw error
    end
  end

  # Creates multiple Jobs based on matrix definition
  defp create_jobs(job, []), do: [job]
  defp create_jobs(job, env_vars_list),
    do: Enum.map(env_vars_list, &create_job(job, &1))

  defp create_job(job, env_vars),
    do: job |> get_job_count() |> set_name(job, env_vars) |> add_env_vars(env_vars)

  defp set_name(:none, job, env_vars) do
    suffix = for e <- env_vars, do: "#{e.name}=#{e.value}"
    new_name = "#{job["name"]} - " <> Enum.join(suffix, ", ")
    Map.put(job, "name", new_name)
  end
  defp set_name(count, job, env_vars) when is_binary(count) do
    index = env_vars |> Enum.at(0) |> Map.get(:value)
    new_name = "#{job["name"]} - #{index}/#{count}"
    Map.put(job, "name", new_name)
  end

  defp add_env_vars(job, env_vars) do
     env_vars = Map.get(job, "env_vars", []) ++ env_vars
     Map.put(job, "env_vars", env_vars)
  end

  defp get_job_count(%{"env_vars" => env_vars}) do
    env_vars
    |> Enum.find(%{}, fn %{"name" => name} -> name == "SEMAPHORE_JOB_COUNT" end)
    |> Map.get("value", :none)
  end
  defp get_job_count(_job), do: :none
end
