defmodule Front.Widgets.ListPipelines do
  require Logger

  alias Front.Models.{
    Pipeline,
    Workflow
  }

  alias Front.TaskSupervisor

  defmodule Front.Widgets.ListPipelines.Element do
    defstruct [
      :id,
      :html_url,
      :state,
      :result,
      :author_avatar_url,
      :author_name,
      :short_commit_id,
      :github_commit_url,
      :commit_message,
      :created_at,
      :done_at,
      :duration,
      :hook_id,
      :branch_id,
      :branch_name,
      :_name,
      :pipeline_name,
      :workflow_id
    ]
  end

  defp timestamp(_, nil), do: nil

  defp timestamp(:beginning, date) do
    case date |> Timex.to_datetime() do
      {:error, _} -> nil
      s -> s |> to_google_timestamp
    end
  end

  defp timestamp(:end, date) do
    case date |> Timex.to_datetime() do
      {:error, _} -> nil
      s -> s |> Timex.end_of_day() |> to_google_timestamp
    end
  end

  defp to_google_timestamp(date) do
    case Timex.to_unix(date) do
      {:error, _} -> nil
      s -> Google.Protobuf.Timestamp.new(seconds: s)
    end
  end

  # credo:disable-for-next-line
  def data(
        project_id,
        branch_name,
        yml_file_path,
        page,
        page_size,
        from,
        to,
        tracing_headers
      ) do
    params = [
      project_id: project_id,
      branch_name: branch_name,
      yml_file_path: yml_file_path,
      page_size: page_size,
      page: page,
      created_after: timestamp(:beginning, from),
      created_before: timestamp(:end, to)
    ]

    options = [pagination: :manual]

    case Pipeline.list(params, options, tracing_headers) do
      {:error, _, _, _, _req} ->
        []

      {:ok, pipelines, pagination, _, _} ->
        workflows =
          pipelines
          |> Enum.map(fn ppl -> ppl.workflow_id end)
          |> Enum.uniq()
          |> fetch_workflows(tracing_headers)

        elements =
          pipelines
          |> Enum.map(fn ppl ->
            construct({
              ppl,
              workflows |> Enum.find(fn wf -> wf.id == ppl.workflow_id end)
            })
          end)
          |> Enum.filter(fn e -> e != nil end)

        {elements, pagination}
    end
  end

  defp fetch_workflows(ids, tracing_headers) do
    Watchman.benchmark("fetch_workflows.duration", fn ->
      ids
      |> pmap(fn id ->
        Workflow.find(id, tracing_headers)
      end)
    end)
  end

  defp pmap(elements, callback) do
    elements
    |> Enum.map(fn el -> Task.Supervisor.async_nolink(TaskSupervisor, fn -> callback.(el) end) end)
    |> Enum.map(fn el ->
      {:ok, element} = Task.yield(el)
      element
    end)
  end

  defp construct({_ppl, nil}), do: nil

  defp construct({ppl, wf}) do
    %Front.Widgets.ListPipelines.Element{
      id: ppl.id,
      html_url: "/workflows/#{wf.id}?pipeline_id=#{wf.root_pipeline_id}",
      state: ppl.state,
      result: ppl.result,
      author_avatar_url: wf.author_avatar_url,
      author_name: wf.author_name,
      short_commit_id: wf.short_commit_id,
      github_commit_url: wf.github_commit_url,
      commit_message: wf.commit_message,
      created_at: DateTime.from_unix!(ppl.timeline.created_at),
      done_at: DateTime.from_unix!(ppl.timeline.done_at),
      duration: ppl.timeline.duration,
      branch_id: wf.branch_id,
      branch_name: wf.branch_name,
      _name: wf._name,
      pipeline_name: ppl.name,
      workflow_id: wf.id
    }
  end
end
