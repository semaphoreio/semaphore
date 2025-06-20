defmodule FrontWeb.JobController do
  require Logger
  use FrontWeb, :controller

  alias Front.{Async, Audit}
  alias Front.MemoryCookie
  alias Front.Models
  alias FrontWeb.Plugs.{FetchPermissions, Header, PageAccess, PublicPageAccess, PutProjectAssigns}

  @private_endpoints ~w(edit_workflow stop)a

  plug(PutProjectAssigns)
  plug(FetchPermissions, scope: "project")

  plug(PublicPageAccess when action not in @private_endpoints)
  plug(PageAccess, [permissions: "project.job.stop"] when action in [:stop])
  plug(PageAccess, [permissions: "project.workflow.manage"] when action in [:edit_workflow])

  plug(Header when action in [:show])

  plug(:verify_job)

  def verify_job(conn, _params) do
    case conn.assigns.job do
      nil ->
        conn
        |> FrontWeb.PageController.status404(%{})
        |> halt()

      %{is_debug_job: true} ->
        conn
        |> put_flash(:alert, "Debug job cannot be accessed.")
        |> redirect(to: project_path(conn, :show, conn.assigns.project.id))
        |> halt()

      _ ->
        conn
    end
  end

  def edit_workflow(conn, _params) do
    Watchman.benchmark("edit_job_workflow.duration", fn ->
      ppl_id = conn.assigns.job.ppl_id

      pipeline = find_pipeline(ppl_id)

      conn |> redirect(to: workflow_path(conn, :edit, pipeline.workflow_id))
    end)
  end

  def show(conn, params) do
    Watchman.benchmark("show.duration", fn ->
      case conn.assigns.authorization do
        :member ->
          common(conn, params, "member.html")

        :guest ->
          common(conn, params, "guest.html")
      end
    end)
  end

  defp common(conn, params, template) do
    org_id = conn.assigns.organization_id
    user_id = conn |> extract_user_id()
    job_id = conn.assigns.job.id
    ppl_id = conn.assigns.job.ppl_id
    self_hosted = conn.assigns.job.self_hosted
    project = conn.assigns.project
    memory = conn.req_cookies["memory"] |> MemoryCookie.values()

    debug_action = debug_or_attach(conn.assigns.job.state)

    fetch_debug_permission = Async.run(fn -> can_debug?(job_id, user_id, debug_action) end)
    fetch_pipeline = Async.run(fn -> find_pipeline(ppl_id) end)
    fetch_organization = Async.run(fn -> Models.Organization.find(org_id) end)
    fetch_user = Async.run(fn -> find_user(user_id, org_id) end)

    {:ok, pipeline} = Async.await(fetch_pipeline)

    fetch_workflow = Async.run(fn -> find_workflow(pipeline.workflow_id) end)
    fetch_hook = Async.run(fn -> find_hook(pipeline.hook_id) end)
    fetch_artifact_logs_url = Async.run(fn -> find_artifact_logs_url(project.id, job_id) end)
    create_token = Async.run(fn -> generate_token(job_id, self_hosted) end)

    {:ok, organization} = Async.await(fetch_organization)
    {:ok, hook} = Async.await(fetch_hook)
    {:ok, workflow} = Async.await(fetch_workflow)
    {:ok, user} = Async.await(fetch_user)
    {:ok, token} = Async.await(create_token)
    {:ok, {:ok, can_debug}} = Async.await(fetch_debug_permission)
    {:ok, {:ok, artifact_logs_url}} = Async.await(fetch_artifact_logs_url)

    block = extract_block(pipeline.blocks, job_id)

    take = extract_take(params)
    pollman_state = extract_state(conn.assigns.job.state)
    fetching = if failed_to_start?(conn.assigns.job), do: "dont_start", else: "ready"
    finished_job = finished_job(conn.assigns.job.state)

    pollman = %{
      state: pollman_state,
      href: "/jobs/#{job_id}/status"
    }

    badge_pollman = %{
      state: pollman_state,
      href: "/jobs/#{conn.assigns.job.id}/status_badge"
    }

    log_state = %{
      dark: memory["logDark"],
      wrap: memory["logWrap"],
      live: memory["logLive"],
      sticky: memory["logSticky"],
      timestamps: memory["logTimestamps"],
      state: conn.assigns.job.state,
      fetching: fetching,
      failure_msg: conn.assigns.job.failure_reason
    }

    assigns =
      %{
        pollman: pollman,
        badge_pollman: badge_pollman,
        log_state: log_state,
        finished_job: finished_job,
        token: token,
        title: compose_title(conn.assigns.job, hook, conn.assigns.project, organization),
        workflow_name: workflow_name(hook),
        take: take,
        organization: organization,
        workflow: workflow,
        pipeline: pipeline,
        hook: hook,
        block: block,
        user: user,
        js: :logs,
        debug_action: debug_action,
        can_debug: can_debug,
        self_hosted: self_hosted,
        permissions: conn.assigns.permissions,
        artifact_logs_url: artifact_logs_url,
        notice: conn |> get_flash(:notice),
        alert: conn |> get_flash(:error)
      }
      |> put_layout_assigns(conn, template)

    render(
      conn,
      template,
      assigns
    )
  end

  defp put_layout_assigns(assigns, conn, template) do
    case template do
      "member.html" ->
        assigns
        |> Map.put(:layout, {FrontWeb.LayoutView, "job.html"})
        |> Front.Breadcrumbs.Job.construct(conn, conn.assigns.job.name)

      "guest.html" ->
        assigns
    end
  end

  def status(conn, params) do
    Watchman.benchmark("status.duration", fn ->
      self_hosted = conn.assigns.job.self_hosted
      pollman_state = extract_state(conn.assigns.job.state)
      debug_action = debug_or_attach(conn.assigns.job.state)
      {_, can_debug} = can_debug?(conn.assigns.job.id, conn.assigns.user_id, debug_action)

      pollman = %{
        state: pollman_state,
        href: "/jobs/#{conn.assigns.job.id}/status"
      }

      data =
        [
          debug_action: debug_action,
          can_debug: can_debug,
          self_hosted: self_hosted,
          pollman: pollman
        ]
        |> inject_nonce(params)

      conn
      |> put_view(FrontWeb.JobView)
      |> put_layout(false)
      |> render("_state.html", data)
    end)
  end

  def status_badge(conn, _params) do
    pollman_state = extract_state(conn.assigns.job.state)

    badge_pollman = %{
      state: pollman_state,
      href: "/jobs/#{conn.assigns.job.id}/status_badge"
    }

    data = [badge_pollman: badge_pollman]

    conn
    |> put_view(FrontWeb.JobView)
    |> put_layout(false)
    |> render("_status_badge.html", data)
  end

  def stop(conn, _params) do
    Watchman.benchmark("stop.duration", fn ->
      job_id = conn.assigns.job.id
      user_id = conn |> extract_user_id()

      case Front.Models.Job.stop(job_id, user_id) do
        {:ok, _} ->
          audit_log(conn, :Stopped, user_id, job_id)

          conn
          |> put_flash(:notice, "Job will be stopped shortly.")
          |> redirect(to: job_path(conn, :show, job_id))

        {:error, _} ->
          conn
          |> put_flash(:alert, "There was a problem with stopping the job.")
          |> redirect(to: job_path(conn, :show, job_id))
      end
    end)
  end

  def logs(conn, params) do
    Watchman.benchmark({"logs.duration", ["#{conn.assigns.job.id}"]}, fn ->
      job = conn.assigns.job

      token = params |> Map.get("token", "0") |> Integer.parse() |> elem(0)

      case JobPage.Events.fetch_events(job.id, token) do
        {:ok, events} ->
          conn
          |> put_resp_content_type("application/json")
          |> send_chunked(200)
          |> send_first_chunk(events.next)
          |> send_events_in_chunks(events.events, per_chunk: 10_000)
          |> send_last_chunk()

        {:error, message} ->
          conn
          |> put_status(500)
          |> json(%{error: message})
      end
    end)
  end

  def timer(conn, _params) do
    Watchman.benchmark("status.duration", fn ->
      job = conn.assigns.job

      json(conn, %{timer: job.timer})
    end)
  end

  def report_time(conn, params) do
    if Map.has_key?(params, "parsing_time") do
      parsing_time = params |> Map.get("parsing_time", 0)

      Task.Supervisor.async_nolink(TaskSupervisor, fn -> report_time(parsing_time) end)
    end

    json(conn, %{})
  end

  def plain_logs(conn, params) do
    Watchman.benchmark("raw_output.duration", fn ->
      job = conn.assigns.job

      starting_event = params |> Map.get("starting_event", "0") |> Integer.parse() |> elem(0)
      take = params |> Map.get("take", "0") |> Integer.parse() |> elem(0)

      if job.self_hosted do
        # The generated token should be valid for 1 minute only
        case Models.Job.generate_token(job.id, 60) do
          "" ->
            conn
            |> put_flash(:alert, "There was a problem finding the raw logs.")
            |> redirect(to: job_path(conn, :show, job.id))

          token ->
            conn
            |> put_status(:temporary_redirect)
            |> redirect(
              external: "https://#{conn.host}/api/v1/logs/#{job.id}?jwt=#{token}&raw=true"
            )
        end
      else
        conn
        |> text(JobPage.Events.raw_logs(job.id, starting_event, take))
      end
    end)
  end

  def events(conn, params) do
    Watchman.benchmark("events.duration", fn ->
      job = conn.assigns.job

      starting_event = params |> Map.get("starting_event", "0") |> Integer.parse() |> elem(0)
      take = params |> Map.get("take", "0") |> Integer.parse() |> elem(0)

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, JobPage.Events.raw_events(job.id, starting_event, take))
    end)
  end

  def audit_log(conn, action, user_id, job_id) do
    conn
    |> Audit.new(:Job, action)
    |> Audit.add(description: audit_desc(action))
    |> Audit.add(resource_id: job_id)
    |> Audit.metadata(requester_id: user_id)
    |> Audit.metadata(project_id: conn.assigns.project.id)
    |> Audit.metadata(project_name: conn.assigns.project.name)
    |> Audit.metadata(pipeline_id: conn.assigns.job.ppl_id)
    |> Audit.metadata(job_id: conn.assigns.job.id)
    |> Audit.log()
  end

  defp audit_desc(:Stopped), do: "Stopped the job"

  # Private

  defp send_first_chunk(conn, next) do
    conn |> chunk(~s({"next": #{next}, "events": [))
    conn
  end

  defp send_events_in_chunks(conn, events, per_chunk: chunk_size) do
    chunks =
      events
      |> Enum.chunk_every(chunk_size)

    chunks_count = Enum.count(chunks)

    chunks
    |> Enum.with_index()
    |> Enum.each(fn {chunk_of_events, index} ->
      if index != chunks_count - 1 do
        chunk(conn, Enum.join(chunk_of_events, ",") <> ",")
      else
        chunk(conn, Enum.join(chunk_of_events, ","))
      end
    end)

    conn
  end

  defp send_last_chunk(conn) do
    conn |> chunk("]}")
    conn
  end

  defp report_time(parsing_time) do
    Watchman.submit("parsing_time.duration", parsing_time, :timing)
  end

  defp compose_title(job, hook, project, organization) do
    "#{job.name}・#{workflow_name(hook)}・#{hook.name}・#{project.name}・#{organization.name}"
  end

  defp workflow_name(hook) do
    hook.commit_message |> String.split("\n") |> hd
  end

  defp extract_user_id(conn) do
    if conn.assigns.anonymous do
      ""
    else
      conn.assigns.user_id
    end
  end

  defp find_pipeline(ppl_id) do
    Models.Pipeline.find(ppl_id, detailed: true)
  end

  defp find_user("", _), do: nil

  defp find_user(user_id, organization_id) do
    Models.User.find_with_opts(user_id, organization_id: organization_id)
  end

  defp find_workflow(wf_id) do
    Models.Workflow.find(wf_id, nil)
  end

  defp find_artifact_logs_url(project_id, job_id) do
    Models.Artifacthub.signed_url(project_id, "jobs", job_id, "agent/job_logs.txt", "HEAD")
  end

  defp find_hook(hook_id) do
    Models.RepoProxy.find(hook_id, nil)
  end

  defp generate_token(job_id, self_hosted) do
    if self_hosted do
      Models.Job.generate_token(job_id)
    else
      ""
    end
  end

  defp extract_take(params) do
    case params |> Map.get("debug", "10000") |> Integer.parse() do
      :error -> 10_000
      {val, _} -> abs(val)
    end
  end

  defp extract_block(blocks, job_id) do
    Enum.find(blocks, fn block ->
      Enum.any?(block.jobs, fn job -> job.id == job_id end)
    end)
  end

  defp extract_state(state) do
    if finished_job(state), do: "done", else: "poll"
  end

  defp finished_job("pending"), do: false
  defp finished_job("running"), do: false
  defp finished_job(_), do: true

  defp failed_to_start?(job) do
    job.timeline.started_at == nil && job.failure_reason != ""
  end

  defp debug_or_attach(job_state)
  defp debug_or_attach("pending"), do: "debug"
  defp debug_or_attach("running"), do: "attach"
  defp debug_or_attach("passed"), do: "debug"
  defp debug_or_attach("failed"), do: "debug"
  defp debug_or_attach("stopped"), do: "debug"

  defp can_debug?(_, user_id, _) when is_nil(user_id) or user_id == "", do: {:ok, false}

  defp can_debug?(job_id, user_id, action = "debug") do
    {:ok, encoded} =
      Cacheman.fetch(:front, cache_key(action, job_id, user_id), [ttl: :timer.hours(1)], fn ->
        {:ok, allowed, _} = Front.Models.Job.can_debug?(job_id, user_id)
        {:ok, encode(allowed)}
      end)

    {:ok, decode(encoded)}
  end

  defp can_debug?(job_id, user_id, action = "attach") do
    {:ok, encoded} =
      Cacheman.fetch(:front, cache_key(action, job_id, user_id), [ttl: :timer.hours(1)], fn ->
        {:ok, allowed, _} = Front.Models.Job.can_attach?(job_id, user_id)
        {:ok, encode(allowed)}
      end)

    {:ok, decode(encoded)}
  end

  defp encode(model), do: :erlang.term_to_binary(model)
  defp decode(model), do: Plug.Crypto.non_executable_binary_to_term(model, [:safe])
  defp cache_key(action, job_id, _user_id), do: "debug_permission/#{action}/#{job_id}"

  defp inject_nonce(data, %{"nonce" => nonce}),
    do: Keyword.merge([script_src_nonce: nonce], data)

  defp inject_nonce(data, _), do: data
end
