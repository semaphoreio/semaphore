defmodule Front.ActivityMonitor.Repo do
  require Logger

  alias Front.Async
  alias Front.Models.User
  alias Util.{Proto, ToTuple}

  @max_activity_monitor_pages 10

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

  @cache :activity_monitor_cache

  # Upper bound for the pipeline stream: its pages (each with a 30s gRPC
  # timeout) plus the job lookups that are started while paging.
  @pipelines_timeout 60_000
  @jobs_timeout 30_000

  # Hard cap for one org-wide fetch. Cachex runs fetch fallbacks in a bare
  # process and waiters block until it reports back, so the fallback must
  # always return.
  @org_activity_timeout 90_000

  def cache_name, do: @cache

  @spec load(String.t(), String.t(), Map.t()) :: {:ok, Data.t()} | {:error, any()}
  def load(org_id, user_id, tracing_headers) do
    fetch_accessible_ids =
      Async.run(fn -> Front.RBAC.Members.list_accessible_projects(org_id, user_id) end)

    case load_org_activity(org_id, tracing_headers) do
      {:ok, activity} ->
        accessable_projects =
          filter_accessible_projects(activity.projects, await(fetch_accessible_ids))

        {:ok,
         struct!(Data,
           org: activity.org,
           accessable_projects: accessable_projects,
           users: activity.users,
           active_pipelines: activity.active_pipelines,
           active_jobs: activity.active_jobs,
           active_debug_sessions: activity.active_debug_sessions
         )}

      {:error, error} ->
        Task.shutdown(fetch_accessible_ids.task, :brutal_kill)
        Logger.error("Failed to collect data for activity monitor page: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Loads the organization-wide activity data (everything except the per-user
  project visibility). The result is cached per organization for a few
  seconds, and concurrent requests for the same organization share a single
  in-flight fetch. Errors are never cached.
  """
  def load_org_activity(org_id, tracing_headers) do
    fallback = fn ->
      case fetch_org_activity_bounded(org_id, tracing_headers) do
        {:ok, activity} -> {:commit, {:ok, activity}}
        {:error, _} = error -> {:ignore, error}
      end
    end

    case Cachex.fetch(@cache, org_id, fallback) do
      {status, {:ok, activity}} when status in [:ok, :commit] -> {:ok, activity}
      {:ignore, {:error, error}} -> {:error, error}
      {:error, error} -> {:error, error}
      other -> {:error, other}
    end
  end

  defp fetch_org_activity_bounded(org_id, tracing_headers) do
    task = Async.run(fn -> fetch_org_activity(org_id, tracing_headers) end)

    case Async.await(task, timeout: @org_activity_timeout) do
      {:ok, {:ok, activity}} -> {:ok, activity}
      {:ok, {:error, error}} -> {:error, error}
      {:ok, other} -> {:error, other}
      {:exit, reason} -> {:error, {:exit, reason}}
      {:error, reason} -> {:error, reason}
    end
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp fetch_org_activity(org_id, tracing_headers) do
    fetch_organization = Async.run(fn -> describe_organization(org_id, tracing_headers) end)
    fetch_projects = Async.run(fn -> list_org_projects(org_id, tracing_headers) end)

    fetch_pipelines_and_jobs =
      Async.run(fn -> list_pipelines_and_jobs(org_id, tracing_headers) end)

    fetch_debugs = Async.run(fn -> list_detailed_debugs(org_id, tracing_headers) end)

    with {:ok, org} <- await(fetch_organization),
         {:ok, projects} <- await(fetch_projects),
         {:ok, {active_pipelines, active_jobs}} <-
           await(fetch_pipelines_and_jobs, @pipelines_timeout + @jobs_timeout),
         {:ok, detailed_debugs} <- await(fetch_debugs, @pipelines_timeout),
         fetch_users <-
           Async.run(fn ->
             list_authors_of(active_pipelines, detailed_debugs, tracing_headers)
           end),
         {:ok, detailed_pipelines} <- combine_data(active_pipelines, active_jobs),
         {:ok, users} <- await(fetch_users) do
      {:ok,
       %{
         org: org,
         projects: projects,
         users: users,
         active_pipelines: detailed_pipelines,
         active_jobs: active_jobs,
         active_debug_sessions: detailed_debugs
       }}
    else
      {:error, error} -> {:error, error}
      error -> {:error, error}
    end
  end

  defp await(task, timeout \\ 30_000) do
    case Async.await(task, timeout: timeout) do
      {:ok, response} -> response
      {:exit, reason} -> {:error, {:exit, reason}}
      error -> error
    end
  end

  defp filter_accessible_projects(projects, {:ok, accessible_project_ids}) do
    accessible = MapSet.new(accessible_project_ids)
    Enum.filter(projects, fn project -> MapSet.member?(accessible, project.id) end)
  end

  defp filter_accessible_projects(_projects, _error), do: []

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
    with {:ok, projects} <- list_org_projects(org_id, tracing_headers) do
      {:ok, Front.RBAC.Members.filter_projects(projects, org_id, user_id)}
    end
  end

  defp list_org_projects(org_id, tracing_headers) do
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

      Watchman.benchmark("activity_monitor.list_unauthorized_projects", fn ->
        InternalApi.Projecthub.ProjectService.Stub.list(
          channel,
          list_request,
          timeout: 30_000,
          metadata: tracing_headers
        )
      end)
      |> case do
        {:ok, res} ->
          if res.metadata.status.code == InternalApi.ResponseStatus.Code.value(:OK) do
            {:ok, construct_list(res.projects)}
          else
            Logger.info("Projecthub list response: #{inspect(res)}")
            {:error, res.metadata.status}
          end

        {:error, error} ->
          {:error, error}
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
    with {:ok, pages} <- list_pipeline_pages(org_id, tracing_headers, fn _ -> nil end) do
      {:ok, Enum.flat_map(pages, fn {pipelines, _} -> pipelines end)}
    end
  end

  @doc """
  Lists active pipelines and, while paging through them, starts the job
  lookup for each page right away. Pipeline pages are chained by page token,
  so they stay sequential, but the job lookups run concurrently with the
  remaining pipeline pages and with each other.
  """
  def list_pipelines_and_jobs(org_id, tracing_headers) do
    start_jobs = fn
      [] -> nil
      pipelines -> start_jobs_fetch(tracing_headers, org_id, ppl_ids_of(pipelines))
    end

    with {:ok, pages} <- list_pipeline_pages(org_id, tracing_headers, start_jobs) do
      pipelines = Enum.flat_map(pages, fn {pipelines, _} -> pipelines end)

      job_tasks =
        case pipelines do
          # Without pipelines, keep asking Zebra for all active jobs of the
          # org (empty ppl_ids means no pipeline filter).
          [] -> [start_jobs_fetch(tracing_headers, org_id, [])]
          _ -> pages |> Enum.map(fn {_, task} -> task end) |> Enum.reject(&is_nil/1)
        end

      with {:ok, jobs} <- await_jobs(job_tasks) do
        {:ok, {pipelines, jobs}}
      end
    end
  end

  defp ppl_ids_of(pipelines), do: Enum.map(pipelines, fn %{ppl_id: id} -> id end)

  defp start_jobs_fetch(tracing_headers, org_id, ppl_ids) do
    Async.run(fn -> list_active_jobs(tracing_headers, org_id, ppl_ids) end)
  end

  defp await_jobs(job_tasks) do
    results =
      job_tasks
      |> Enum.map(fn async -> async.task end)
      |> Task.yield_many(@jobs_timeout)

    Enum.each(results, fn
      {task, nil} -> Task.shutdown(task, :brutal_kill)
      _ -> :ok
    end)

    results
    |> Enum.reduce_while({:ok, []}, fn
      {_task, {:ok, {:ok, jobs}}}, {:ok, acc} -> {:cont, {:ok, [jobs | acc]}}
      {_task, {:ok, {:error, error}}}, _ -> {:halt, {:error, error}}
      {_task, {:exit, reason}}, _ -> {:halt, {:error, {:exit, reason}}}
      {_task, nil}, _ -> {:halt, {:error, :timeout}}
    end)
    |> case do
      {:ok, pages} ->
        # Duplicated pipelines across pages would fetch the same jobs twice.
        {:ok, pages |> Enum.reverse() |> Enum.concat() |> Enum.uniq_by(&Map.get(&1, :id))}

      error ->
        error
    end
  end

  defp list_pipeline_pages(org_id, tracing_headers, on_page) do
    alias InternalApi.Plumber.ListActivityRequest, as: Req
    alias InternalApi.Plumber.PipelineService

    Watchman.benchmark("activity_monitor.list_pipeline_activity", fn ->
      url = Application.fetch_env!(:front, :pipeline_api_grpc_endpoint)
      {:ok, channel} = GRPC.Stub.connect(url)

      options = [timeout: 30_000, metadata: tracing_headers]

      list_all_pages(fn page_token ->
        request =
          Req.new(
            page_size: 300,
            page_token: page_token,
            order: Req.Order.value(:BY_CREATION_TIME_DESC),
            direction: Req.Direction.value(:NEXT),
            organization_id: org_id
          )

        case PipelineService.Stub.list_activity(channel, request, options) do
          {:ok, response} ->
            page = Proto.to_map!(response, transformations: tf_map())
            pipelines = Map.get(page, :pipelines, [])

            {:ok, [{pipelines, on_page.(pipelines)}], Map.get(page, :next_page_token, "")}

          {:error, error} ->
            {:error, error}
        end
      end)
    end)
  end

  # List Debug Sessions

  def list_active_debugs(org_id, tracing_headers) do
    alias InternalApi.ServerFarm.Job.JobService
    alias InternalApi.ServerFarm.Job.ListDebugSessionsRequest

    Watchman.benchmark("activity_monitor.list_debug_sessions", fn ->
      url = Application.fetch_env!(:front, :job_api_grpc_endpoint)
      {:ok, channel} = GRPC.Stub.connect(url)

      options = [timeout: 30_000, metadata: tracing_headers]

      list_all_pages(fn page_token ->
        request =
          %{
            page_size: 500,
            page_token: page_token,
            order: :BY_CREATION_TIME_DESC,
            debug_session_states: [:PENDING, :ENQUEUED, :SCHEDULED, :STARTED],
            types: [:JOB],
            organization_id: org_id
          }
          |> Proto.deep_new!(ListDebugSessionsRequest)

        case JobService.Stub.list_debug_sessions(channel, request, options) do
          {:ok, response} ->
            response
            |> Proto.to_map!(transformations: tf_map())
            |> extract_debugs_page()

          {:error, error} ->
            {:error, error}
        end
      end)
    end)
  end

  defp extract_debugs_page(payload = %{status: %{code: :OK}, debug_sessions: debugs}),
    do: {:ok, debugs, Map.get(payload, :next_page_token, "")}

  defp extract_debugs_page(%{status: %{message: msg}}), do: {:error, msg}
  defp extract_debugs_page(error), do: {:error, error}

  def list_detailed_debugs(org_id, tracing_headers) do
    with {:ok, debug_sessions} <- list_active_debugs(org_id, tracing_headers),
         {:ok, debugged_ppls} <- describe_debugged_ppls(debug_sessions, tracing_headers) do
      merge_pipeline_data(debug_sessions, debugged_ppls)
    end
  end

  defp describe_debugged_ppls([], _tracing_headers), do: {:ok, []}

  defp describe_debugged_ppls(debug_sessions, tracing_headers) do
    debug_sessions
    |> Enum.map(fn debug -> debug.debugged_job.ppl_id end)
    |> Enum.uniq()
    |> describe_many_ppls(tracing_headers)
  end

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
    |> Enum.flat_map(fn ppl ->
      if ppl.promoter_id != "" do
        [ppl.requester_id, ppl.promoter_id]
      else
        [ppl.requester_id]
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

      options = [timeout: 30_000, metadata: tracing_headers]

      list_all_pages(fn page_token ->
        request =
          %{
            page_size: 500,
            page_token: page_token,
            order: :BY_CREATION_TIME_DESC,
            organization_id: org_id,
            ppl_ids: ppl_ids,
            only_debug_jobs: false,
            job_states: [:PENDING, :ENQUEUED, :SCHEDULED, :STARTED]
          }
          |> Proto.deep_new!(ListRequest)

        case JobService.Stub.list(channel, request, options) do
          {:ok, response} ->
            response
            |> Proto.to_map!(transformations: tf_map())
            |> extract_jobs_page()

          {:error, error} ->
            {:error, error}
        end
      end)
    end)
  end

  defp tf_map, do: %{Google.Protobuf.Timestamp => {__MODULE__, :timestamp_to_datetime}}

  def timestamp_to_datetime(_name, %{nanos: 0, seconds: 0}), do: :invalid_datetime

  def timestamp_to_datetime(_name, %{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    ts_date_time
  end

  defp extract_jobs_page(payload = %{status: %{code: :OK}, jobs: jobs}),
    do: {:ok, jobs, Map.get(payload, :next_page_token, "")}

  defp extract_jobs_page(%{status: %{message: msg}}), do: {:error, msg}
  defp extract_jobs_page(error), do: {:error, error}

  defp list_all_pages(fetch_page) do
    list_all_pages(fetch_page, "", MapSet.new(), [], 0)
  end

  defp list_all_pages(fetch_page, page_token, seen_tokens, pages, page_count) do
    case pagination_stop_reason(page_token, seen_tokens, page_count) do
      nil ->
        fetch_pagination_page(fetch_page, page_token, seen_tokens, pages, page_count)

      reason ->
        log_pagination_stop(reason, page_token)
        finalize_pages(pages)
    end
  end

  defp pagination_stop_reason(_page_token, _seen_tokens, page_count)
       when page_count >= @max_activity_monitor_pages,
       do: :max_pages

  defp pagination_stop_reason(page_token, seen_tokens, _page_count) do
    if page_token != "" and MapSet.member?(seen_tokens, page_token) do
      :token_repeated
    else
      nil
    end
  end

  defp fetch_pagination_page(fetch_page, page_token, seen_tokens, pages, page_count) do
    seen_tokens = MapSet.put(seen_tokens, page_token)

    case fetch_page.(page_token) do
      {:ok, records, next_page_token} ->
        continue_pagination(
          fetch_page,
          page_token,
          next_page_token || "",
          seen_tokens,
          [records | pages],
          page_count
        )

      {:error, _} = error ->
        error
    end
  end

  defp continue_pagination(_fetch_page, _page_token, "", _seen_tokens, pages, _page_count),
    do: finalize_pages(pages)

  defp continue_pagination(_fetch_page, page_token, page_token, _seen_tokens, pages, _page_count) do
    log_pagination_stop(:token_unchanged, page_token)
    finalize_pages(pages)
  end

  defp continue_pagination(
         fetch_page,
         _page_token,
         next_page_token,
         seen_tokens,
         pages,
         page_count
       ) do
    list_all_pages(fetch_page, next_page_token, seen_tokens, pages, page_count + 1)
  end

  defp log_pagination_stop(:max_pages, _page_token) do
    Logger.error(
      "Activity monitor pagination aborted: reached max page limit (max_pages=#{@max_activity_monitor_pages})"
    )
  end

  defp log_pagination_stop(:token_repeated, page_token) do
    Logger.error(
      "Activity monitor pagination aborted: pagination did not advance (token=#{inspect(page_token)})"
    )
  end

  defp log_pagination_stop(:token_unchanged, page_token) do
    Logger.error(
      "Activity monitor pagination aborted: pagination token did not change (token=#{inspect(page_token)})"
    )
  end

  defp finalize_pages(pages) do
    {:ok, pages |> Enum.reverse() |> List.flatten()}
  end

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
    ppls_by_id = index_first_by(debugged_ppls, fn ppl -> ppl.ppl_id end)

    debug_sessions
    |> Enum.map(fn debug = %{debugged_job: debugged_job} ->
      debug_ppl = Map.get(ppls_by_id, debugged_job.ppl_id)

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
    jobs_by_key = Enum.group_by(active_jobs, fn job -> {job.ppl_id, job.name, job.index} end)

    active_pipelines
    |> Enum.map(fn pipeline ->
      blocks =
        pipeline.blocks
        |> Enum.map(fn block ->
          {jobs, _} =
            block.jobs
            |> Enum.reduce({[], MapSet.new()}, fn job, {block_jobs, used_ids} ->
              replace_job(pipeline.ppl_id, job, block_jobs, {jobs_by_key, used_ids})
            end)

          block |> Map.put(:jobs, Enum.reverse(jobs))
        end)

      pipeline |> Map.put(:blocks, blocks)
    end)
    |> ToTuple.ok()
  end

  # Within a block, each Zebra job is used at most once (tracked by id), and
  # the first matching job in Zebra order wins.
  defp replace_job(ppl_id, p_job = %{status: "scheduled"}, block_jobs, {jobs_by_key, used_ids}) do
    full_job =
      jobs_by_key
      |> Map.get({ppl_id, p_job.name, p_job.index}, [])
      |> Enum.find(p_job, fn job -> not MapSet.member?(used_ids, Map.get(job, :id, "")) end)

    {[full_job | block_jobs], MapSet.put(used_ids, Map.get(full_job, :id))}
  end

  defp replace_job(_ppl_id, job = %{status: "pending"}, block_jobs, {_jobs_by_key, used_ids}),
    do: {[job | block_jobs], used_ids}

  defp index_first_by(entries, key_fun) do
    Enum.reduce(entries, %{}, fn entry, acc -> Map.put_new(acc, key_fun.(entry), entry) end)
  end
end
