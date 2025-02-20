defmodule Front.Widgets.ListWorkflows do
  require Logger
  alias Front.Models.Workflow
  alias Front.RBAC.Members

  defmodule Front.Widgets.ListWorkflows.Element do
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
      :project_name,
      :pipeline
    ]
  end

  def skip_workflows(nil, _), do: false
  def skip_workflows("", _), do: false
  def skip_workflows([], _), do: false
  def skip_workflows(_, result) when length(result) > 0, do: false
  def skip_workflows(orginal, []) when is_list(orginal), do: true
  def skip_workflows(orginal, []) when is_binary(orginal), do: true

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
        project_ids,
        branch_name,
        requester_id,
        org_id,
        user_id,
        page,
        page_size,
        from,
        to,
        tracing_headers
      ) do
    p_ids = filter_projects(project_ids, org_id, user_id)

    if skip_workflows(project_ids, p_ids) do
      {[], Workflow.empty_page()}
    else
      params = [
        project_ids: p_ids,
        branch_name: branch_name,
        organization_id: org_id,
        requester_id: requester_id,
        page_size: page_size,
        page: page,
        created_after: timestamp(:beginning, from),
        created_before: timestamp(:end, to)
      ]

      options = [pagination: :manual]

      list_workflows(params, options, tracing_headers)
    end
  end

  defp list_workflows(params, options, tracing_headers) do
    case Workflow.list(params, options, tracing_headers) do
      {:error, _, _, _} ->
        Logger.debug(fn -> "Workflow.List returned #{inspect(nil)}" end)
        []

      {:ok, workflows, pagination, _, _} ->
        pipelines =
          workflows
          |> Enum.map(fn workflow ->
            workflow.pipelines
            |> Enum.find(&(&1.id == workflow.root_pipeline_id))
          end)

        Logger.debug(fn -> "Pipelines #{inspect(pipelines)}" end)

        elements =
          workflows
          |> Enum.map(fn wf ->
            construct({
              wf,
              pipelines |> Enum.find(fn ppl -> ppl.workflow_id == wf.id end)
            })
          end)
          |> Enum.filter(fn e -> e != nil end)

        {elements, pagination}
    end
  end

  defp filter_projects(project_ids, org_id, user_id) when is_list(project_ids) do
    project_ids
    |> Enum.map(fn project_id -> %{id: project_id} end)
    |> Members.filter_projects(org_id, user_id)
    |> Enum.map(fn resource -> resource.id end)
  end

  defp filter_projects(nil, _org_id, _user_id), do: []
  defp filter_projects("", _org_id, _user_id), do: []

  defp filter_projects(project_id, org_id, user_id),
    do: filter_projects([project_id], org_id, user_id)

  defp construct({_wf, nil}), do: nil

  defp construct({wf, ppl}) do
    %Front.Widgets.ListWorkflows.Element{
      id: wf.id,
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
      project_name: wf.project_name,
      pipeline: ppl
    }
  end
end
