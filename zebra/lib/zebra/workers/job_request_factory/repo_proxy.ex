defmodule Zebra.Workers.JobRequestFactory.RepoProxy do
  require Logger
  alias InternalApi.RepoProxy.DescribeRequest, as: Request
  alias InternalApi.RepoProxy.RepoProxyService.Stub

  def extract_hook_id(job = %{build_id: nil}, :pipeline_job),
    do: {:stop_job_processing, "Job #{job.id} is missing build_id"}

  def extract_hook_id(job, :pipeline_job) do
    alias Zebra.Models.Task

    case Task.find(job.build_id) do
      {:ok, task} ->
        {:ok, task.hook_id}

      {:error, :not_found} ->
        {:stop_job_processing, "Build #{job.build_id} not found"}
    end
  end

  def extract_hook_id(job, :debug_job) do
    alias Zebra.Models.{Debug, Job}

    case Debug.from_jobs() |> Debug.find_by_job_id(job.id) do
      {:ok, debug} ->
        case Job.find(debug.debugged_id) do
          {:error, _} ->
            {:stop_job_processing, "Debugged job #{debug.debugged_id} not found"}

          {:ok, debugged_job} ->
            job_type = Job.detect_type(debugged_job)
            extract_hook_id(debugged_job, job_type)
        end

      {:error, _} ->
        {:stop_job_processing, "Debug record for job #{job.id} not found"}
    end
  end

  def extract_hook_id(_, :project_debug_job),
    do: {:ok, nil}

  def find(nil), do: {:ok, nil}

  def find(hook_id) do
    case Cachex.fetch(:zebra_cache, "repo_proxy-#{hook_id}", &find_/1) do
      {:ignore, {:stop_job_processing, message}} -> {:stop_job_processing, message}
      {:ignore, :error} -> {:error, :communication_error}
      {_, value} -> {:ok, value}
    end
  end

  def find_(key) do
    hook_id = key |> String.replace_prefix("repo_proxy-", "")

    Watchman.benchmark("zebra.external.repo_proxy.describe", fn ->
      req = Request.new(hook_id: hook_id)

      with {:ok, endpoint} <- Application.fetch_env(:zebra, :repo_proxy_api_endpoint),
           {:ok, channel} <- GRPC.Stub.connect(endpoint),
           {:ok, res} <- Stub.describe(channel, req, timeout: 30_000) do
        if res.status.code == 0 do
          {:commit, res.hook}
        else
          Logger.info("RepoProxy##{hook_id}, not found, #{inspect(res)}")

          {:ignore, {:stop_job_processing, "Hook #{hook_id} not found"}}
        end
      else
        e ->
          Logger.info("Failed to fetch info for RepoProxy##{hook_id}, #{inspect(e)}")

          {:ignore, :error}
      end
    end)
  end
end
