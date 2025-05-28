defmodule Front.ActivityMonitor.Repo do
  require Logger

  alias Front.Async
  alias Front.Models.User
  alias Util.{Proto, ToTuple}

  defmodule Data do
    use TypedStruct

    typedstruct do
      field(:org, Map.t(), enforce: true)
      field(:accessable_projects, [InternalApi.Projecthub.Project.t()], enforce: true)
      field(:users, [Front.Models.User.t()], enforce: true)
      field(:active_pipelines, [Map.t()], enforce: true)
      field(:active_jobs, [Map.t()], enforce: true)
      field(:active_debug_sessions, [Map.t()], enforce: true)
    end
  end

  @spec load(String.t(), String.t(), Map.t()) :: {:ok, Data.t()} | {:error, String.t()}
  def load(org_id, user_id, tracing_headers) do
    fetch_organization = Async.run(fn -> describe_organization(org_id, tracing_headers) end)

    fetch_accessable_projects =
      Async.run(fn -> list_projects(org_id, user_id, tracing_headers) end)

    fetch_active_pipelines = Async.run(fn -> list_pipeline_activity(org_id, tracing_headers) end)

    fetch_debugs = Async.run(fn -> list_active_debugs(org_id, tracing_headers) end)

    with {:ok, org} <- await(fetch_organization),
         {:ok, accessable_projects} <- await(fetch_accessable_projects),
         {:ok, active_pipelines} <- await(fetch_active_pipelines),
         {:ok, debug_sessions} <- await(fetch_debugs),
         ppl_ids <- Enum.map(active_pipelines, fn %{ppl_id: id} -> id end),
         debugged_ppl_ids <- Enum.map(debug_sessions, fn debug -> debug.debugged_job.ppl_id end),
         fetch_users <-
           Async.run(fn -> list_authors_of(active_pipelines, debug_sessions, tracing_headers) end),
         fetch_jobs <- Async.run(fn -> list_active_jobs(tracing_headers, org_id, ppl_ids) end),
         fetch_debugged_ppls <-
           Async.run(fn -> describe_many_ppls(debugged_ppl_ids, tracing_headers) end),
         {:ok, users} <- await(fetch_users),
         {:ok, active_jobs} <- await(fetch_jobs),
         {:ok, debugged_ppls} <- await(fetch_debugged_ppls),
         {:ok, detailed_debugs} <- merge_pipeline_data(debug_sessions, debugged_ppls),
         {:ok, detailed_pipelines} <- combine_data(active_pipelines, active_jobs) do
      {:ok,
       struct!(Data,
         org: org,
         accessable_projects: accessable_projects,
         users: users,
         active_pipelines: detailed_pipelines,
         active_jobs: active_jobs,
         active_debug_sessions: detailed_debugs
       )}
    else
      {:error, error} ->
        Logger.error("Failed to collect data for activity monitor page: #{inspect(error)}")
        {:error, error}

      error ->
        Logger.error("Failed to collect data for activity monitor page: #{inspect(error)}")
        {:error, error}
    end
  end

  defp await(func) do
    case Async.await(func) do
      {:ok, response} -> response
      error -> error
    end
  end

  # Describe organization

  def describe_organization(org_id, tracing_headers) do
    alias InternalApi.Organization.{DescribeRequest, OrganizationService}

    Watchman.benchmark("activity_monitor.describe_organization", fn ->
      url = Application.fetch_env!(:front, :organization_api_grpc_endpoint)
      {:ok, channel} = GRPC.Stub.connect(url)

      request = DescribeRequest.new(org_id: org_id, include_quotas: true)

      options = [timeout: 30_000, metadata: tracing_headers]

      case OrganizationService.Stub.describe(channel, request, options) do
        {:ok, response} ->
          response |> Proto.to_map(transformations: tf_map()) |> extract_org()

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  defp extract_org({:ok, %{status: %{code: :OK}, organization: org}}), do: {:ok, org}
  defp extract_org({:ok, %{status: %{message: msg}}}), do: {:error, msg}
  defp extract_org(error), do: error

  # List projects

  def list_projects(org_id, user_id, tracing_headers) do
    Watchman.benchmark("activity_monitor.list_projects", fn ->
      req = InternalApi.Projecthub.RequestMeta.new(org_id: org_id)
      pagination = InternalApi.Projecthub.PaginationRequest.new(page: 1, page_size: 300)
      url = Application.fetch_env!(:front, :projecthub_grpc_endpoint)
      {:ok, channel} = GRPC.Stub.connect(url)

      list_request =
        InternalApi.Projecthub.ListRequest.new(
          metadata: req,
          pagination: pagination
        )

      {:ok, res} =
        Watchman.benchmark("activity_monitor.list_unauthorized_projects", fn ->
          InternalApi.Projecthub.ProjectService.Stub.list(
            channel,
            list_request,
            timeout: 30_000,
            metadata: tracing_headers
          )
        end)

      if res.metadata.status.code == InternalApi.ResponseStatus.Code.value(:OK) do
        projects =
          res.projects
          |> construct_list()
          |> Front.RBAC.Members.filter_projects(org_id, user_id)

        {:ok, projects}
      else
        Logger.info("Projecthub list response: #{inspect(res)}")
        {:error, res.metadata.status}
      end
    end)
  end

  defp construct_list(raw_projects) do
    Enum.map(raw_projects, fn project ->
      %{
        name: project.metadata.name,
        id: project.metadata.id,
        description: project.metadata.description
      }
    end)
  end

  # List active pipelines

  def list_pipeline_activity(org_id, tracing_headers) do
    alias InternalApi.Plumber.ListActivityRequest, as: Req
    alias InternalApi.Plumber.PipelineService

    Watchman.benchmark("activity_monitor.list_pipeline_activity", fn ->
      url = Application.fetch_env!(:front, :pipeline_api_grpc_endpoint)
      {:ok, channel} = GRPC.Stub.connect(url)

      request =
        Req.new(
          page_size: 300,
          page_token: "",
          order: Req.Order.value(:BY_CREATION_TIME_DESC),
          direction: Req.Direction.value(:NEXT),
          organization_id: org_id
        )

      options = [timeout: 30_000, metadata: tracing_headers]

      case PipelineService.Stub.list_activity(channel, request, options) do
        {:ok, response} ->
          response
          |> Proto.to_map!(transformations: tf_map())
          |> Map.get(:pipelines)
          |> ToTuple.ok()

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  # List Debug Sessions

  def list_active_debugs(org_id, tracing_headers) do
    alias InternalApi.ServerFarm.Job.JobService
    alias InternalApi.ServerFarm.Job.ListDebugSessionsRequest

    Watchman.benchmark("activity_monitor.list_debug_sessions", fn ->
      url = Application.fetch_env!(:front, :job_api_grpc_endpoint)
      {:ok, channel} = GRPC.Stub.connect(url)

      request =
        %{
          page_size: 500,
          page_token: "",
          order: :BY_CREATION_TIME_DESC,
          debug_session_states: [:PENDING, :ENQUEUED, :SCHEDULED, :STARTED],
          types: [:JOB],
          organization_id: org_id
        }
        |> Proto.deep_new!(ListDebugSessionsRequest)

      options = [timeout: 30_000, metadata: tracing_headers]

      case JobService.Stub.list_debug_sessions(channel, request, options) do
        {:ok, response} ->
          response |> Proto.to_map(transformations: tf_map()) |> extract_debugs()

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  defp extract_debugs({:ok, %{status: %{code: :OK}, debug_sessions: debugs}}), do: {:ok, debugs}
  defp extract_debugs({:ok, %{status: %{message: msg}}}), do: {:error, msg}
  defp extract_debugs(error), do: error

  # Describe_many pipelines which jobs are being debugged

  def describe_many_ppls(debugged_ppl_ids, tracing_headers) do
    alias InternalApi.Plumber.DescribeManyRequest
    alias InternalApi.Plumber.PipelineService

    Watchman.benchmark("activity_monitor.list_pipeline_activity", fn ->
      url = Application.fetch_env!(:front, :pipeline_api_grpc_endpoint)
      {:ok, channel} = GRPC.Stub.connect(url)

      request = DescribeManyRequest.new(ppl_ids: debugged_ppl_ids)

      options = [timeout: 30_000, metadata: tracing_headers]

      case PipelineService.Stub.describe_many(channel, request, options) do
        {:ok, response} ->
          response |> Proto.to_map(transformations: tf_map()) |> extract_ppls()

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  defp extract_ppls({:ok, %{response_status: %{code: :OK}, pipelines: ppls}}), do: {:ok, ppls}
  defp extract_ppls({:ok, %{response_status: %{message: msg}}}), do: {:error, msg}
  defp extract_ppls(error), do: error

  # List Users

  def list_authors_of(active_pipelines, debug_sessions, tracing_headers) do
    active_pipelines
    |> Enum.reduce([], fn ppl, acc ->
      if ppl.promoter_id != "" do
        acc ++ [ppl.requester_id, ppl.promoter_id]
      else
        acc ++ [ppl.requester_id]
      end
    end)
    |> Enum.concat(Enum.map(debug_sessions, fn debug -> debug.debug_user_id end))
    |> Enum.uniq()
    |> get_users(tracing_headers)
    |> ok_err_tuple()
  end

  defp get_users(list, tracing_headers) when is_list(list) and length(list) > 0,
    do: User.find_many(list, tracing_headers)

  defp get_users(_, _), do: []

  defp ok_err_tuple(nil), do: {:error, nil}
  defp ok_err_tuple(list), do: {:ok, list}

  # List jobs

  def list_active_jobs(tracing_headers, org_id, ppl_ids) do
    alias InternalApi.ServerFarm.Job.JobService
    alias InternalApi.ServerFarm.Job.ListRequest

    Watchman.benchmark("activity_monitor.list_active_jobs", fn ->
      url = Application.fetch_env!(:front, :job_api_grpc_endpoint)
      {:ok, channel} = GRPC.Stub.connect(url)

      request =
        %{
          page_size: 500,
          page_token: "",
          order: :BY_CREATION_TIME_DESC,
          organization_id: org_id,
          ppl_ids: ppl_ids,
          only_debug_jobs: false,
          job_states: [:PENDING, :ENQUEUED, :SCHEDULED, :STARTED]
        }
        |> Proto.deep_new!(ListRequest)

      options = [timeout: 30_000, metadata: tracing_headers]

      case JobService.Stub.list(channel, request, options) do
        {:ok, response} ->
          response |> Proto.to_map(transformations: tf_map()) |> extract_jobs()

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  defp tf_map, do: %{Google.Protobuf.Timestamp => {__MODULE__, :timestamp_to_datetime}}

  def timestamp_to_datetime(_name, %{nanos: 0, seconds: 0}), do: :invalid_datetime

  def timestamp_to_datetime(_name, %{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    ts_date_time
  end

  defp extract_jobs({:ok, %{status: %{code: :OK}, jobs: jobs}}), do: {:ok, jobs}
  defp extract_jobs({:ok, %{status: %{message: msg}}}), do: {:error, msg}
  defp extract_jobs(error), do: error

  # Stop Job

  def stop_job(request) do
    alias InternalApi.ServerFarm.Job.JobService

    Watchman.benchmark("activity_monitor.stop_job", fn ->
      url = Application.fetch_env!(:front, :job_api_grpc_endpoint)
      {:ok, channel} = GRPC.Stub.connect(url)

      options = [timeout: 30_000, metadata: %{}]

      JobService.Stub.stop(channel, request, options)
    end)
  end

  # Merge debug_sessions and debugged_pipelines data

  def merge_pipeline_data(debug_sessions, debugged_ppls) do
    debug_sessions
    |> Enum.map(fn debug = %{debugged_job: debugged_job} ->
      debug_ppl = Enum.find(debugged_ppls, fn ppl -> ppl.ppl_id == debugged_job.ppl_id end)

      debugged_job = Map.put(debugged_job, :pipeline, debug_ppl)

      Map.put(debug, :debugged_job, debugged_job)
    end)
    |> ToTuple.ok()
  end

  # Combine pipeline and jobs data

  @doc """
  Replaces all scheduled jobs within pipelines that only have pending/scheduled
  status and ids with full job description received from Zebra
  """
  def combine_data(active_pipelines, active_jobs) do
    active_pipelines
    |> Enum.map(fn pipeline ->
      blocks =
        pipeline.blocks
        |> Enum.map(fn block ->
          {jobs, _} =
            block.jobs
            |> Enum.reduce({[], active_jobs}, fn job, {block_jobs, full_jobs} ->
              replace_job(pipeline.ppl_id, job, block_jobs, full_jobs)
            end)

          block |> Map.put(:jobs, jobs)
        end)

      pipeline |> Map.put(:blocks, blocks)
    end)
    |> ToTuple.ok()
  end

  defp replace_job(ppl_id, p_job = %{status: "scheduled"}, block_jobs, full_jobs) do
    full_job =
      Enum.find(full_jobs, p_job, fn job ->
        job.ppl_id == ppl_id and job.name == p_job.name and job.index == p_job.index
      end)

    block_jobs = block_jobs ++ [full_job]

    full_jobs =
      Enum.reject(full_jobs, fn job -> Map.get(job, :id, "") == Map.get(full_job, :id) end)

    {block_jobs, full_jobs}
  end

  defp replace_job(_ppl_id, job = %{status: "pending"}, block_jobs, full_jobs),
    do: {block_jobs ++ [job], full_jobs}
end
