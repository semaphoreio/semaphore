defmodule Front.Widgets.Fetcher do
  require Logger

  alias Front.{Decorators, Models}

  alias Front.Widgets.{
    Duration,
    ListPipelines,
    ListWorkflows,
    Ratio
  }

  def fetch("duration_pipelines", _filters, _ctx), do: nil
  def fetch("ratio_pipelines", _filters, _ctx), do: nil

  def fetch("list_pipelines", filters, ctx) do
    filters = map_filters(filters)

    params =
      [
        page_size: 10,
        page_token: ctx.page_token,
        project_id: filters.project_id,
        label: filters.branch,
        yml_file_path: filters.pipeline_file,
        git_ref_types: git_ref_types(filters.branch),
        direction: map_pipeline_direction(ctx.direction),
        created_after: timestamp(:beginning, ctx.from),
        created_before: timestamp(:end, ctx.to)
      ]
      |> drop_empty_keys()

    {ppls, next_page_token, previous_page_token} =
      case {Models.Pipeline.list_keyset(params), ctx.page_token} do
        {{:error, _}, ""} -> {[], "", ""}
        {response, _} -> response
      end

    workflows = Decorators.Workflow.decorate_with_pipelines(ppls)

    previous = if previous_page_token != "", do: previous_page_token, else: nil
    next = if next_page_token != "", do: next_page_token, else: nil
    newest = if ctx.page_token == "", do: false, else: true
    visible = if previous != nil or next != nil, do: true, else: false

    pagination = %{
      visible: visible,
      newest: newest,
      previous: previous,
      next: next
    }

    pollman = %{
      state: "poll",
      href: "/dashboards/#{ctx.dashboard_id}/#{ctx.widget_idx}/poll",
      params: [
        page_token: ctx.page_token
      ]
    }

    %{workflows: workflows, pagination: pagination, pollman: pollman}
  end

  def fetch("list_workflows", filters, ctx) do
    filters = map_filters(filters)

    user_id =
      case filters.github_uid do
        "{{github_uid}}" -> ctx.user_id
        _ -> ""
      end

    params =
      [
        page_size: 10,
        page_token: ctx.page_token,
        organization_id: ctx.org_id,
        requester_id: user_id,
        project_id: filters.project_id,
        label: filters.branch,
        git_ref_types: git_ref_types(filters.branch),
        direction: map_workflow_direction(ctx.direction),
        created_after: timestamp(:beginning, ctx.from),
        created_before: timestamp(:end, ctx.to)
      ]
      |> drop_empty_keys()

    {wfs, next_page_token, previous_page_token} = Models.Workflow.list_keyset(params)
    workflows = Decorators.Workflow.decorate_many(wfs)

    previous = if previous_page_token != "", do: previous_page_token, else: nil
    next = if next_page_token != "", do: next_page_token, else: nil
    newest = if ctx.page_token == "", do: false, else: true
    visible = if previous != nil or next != nil, do: true, else: false

    pagination = %{
      visible: visible,
      newest: newest,
      previous: previous,
      next: next
    }

    pollman = %{
      state: "poll",
      href: "/dashboards/#{ctx.dashboard_id}/#{ctx.widget_idx}/poll",
      params: [
        page_token: ctx.page_token
      ]
    }

    %{workflows: workflows, pagination: pagination, pollman: pollman}
  end

  defp map_workflow_direction("next"),
    do: InternalApi.PlumberWF.ListKeysetRequest.Direction.value(:NEXT)

  defp map_workflow_direction("previous"),
    do: InternalApi.PlumberWF.ListKeysetRequest.Direction.value(:PREVIOUS)

  defp map_workflow_direction(_), do: map_workflow_direction("next")

  defp map_pipeline_direction("next"),
    do: InternalApi.Plumber.ListKeysetRequest.Direction.value(:NEXT)

  defp map_pipeline_direction("previous"),
    do: InternalApi.Plumber.ListKeysetRequest.Direction.value(:PREVIOUS)

  defp map_pipeline_direction(_), do: map_pipeline_direction("next")

  defp drop_empty_keys(keyword) do
    keys = keyword |> Enum.filter(fn {_, v} -> v == "" end) |> Keyword.keys()
    Keyword.drop(keyword, keys)
  end

  # credo:disable-for-next-line
  def fetch(
        widget,
        dashboard,
        index,
        user_id,
        org_id,
        page,
        page_size,
        from,
        to,
        tracing_headers \\ nil
      )

  # credo:disable-for-next-line
  def fetch(
        {:list_workflows, {filters, name}},
        dashboard,
        index,
        user_id,
        org_id,
        page,
        page_size,
        from,
        to,
        tracing_headers
      ) do
    Logger.info(inspect(name))
    Logger.info(inspect(filters))

    {project_id, branch_name, filters} = filters |> extract_filters

    requester_id =
      case filters |> Map.pop("github_uid", "") do
        {"{{github_uid}}", _} -> user_id
        {guid, _} -> guid
      end

    {workflows, pagination} =
      ListWorkflows.data(
        project_id,
        branch_name,
        requester_id,
        org_id,
        user_id,
        page,
        page_size,
        from,
        to,
        tracing_headers
      )

    Logger.debug(fn -> "ListWorkflows.data returned #{inspect(workflows)}" end)

    path = "/dashboards/#{dashboard.id}/#{index}/poll"

    Front.Pagination.construct_links(
      path,
      pagination.current_page,
      pagination.total_pages
    )

    pagination = %{current: pagination.current_page, filters: %{requester: false}, href: path}

    %{
      type: :list_workflows,
      name: name,
      workflows: workflows,
      pagination: pagination,
      path: path,
      range: Date.range(from, to)
    }
  end

  # credo:disable-for-next-line
  def fetch(
        {:duration_pipelines, {filters, name}},
        _dashboard,
        _index,
        user_id,
        org_id,
        _page,
        _page_size,
        from,
        to,
        tracing_headers
      ) do
    Logger.info(inspect(name))
    Logger.info(inspect(filters))

    {project_id, branch_name, filters} = filters |> extract_filters
    {yml_file_path, _} = filters |> Map.pop("pipeline_file", "")

    Duration.data(
      project_id,
      branch_name,
      yml_file_path,
      org_id,
      user_id,
      from,
      to,
      tracing_headers
    )
  end

  # credo:disable-for-next-line
  def fetch(
        {:ratio_pipelines, {filters, name}},
        _dashboard,
        _index,
        user_id,
        org_id,
        _page,
        _page_size,
        from,
        to,
        tracing_headers
      ) do
    Logger.info(inspect(name))
    Logger.info(inspect(filters))

    {project_id, branch_name, filters} = filters |> extract_filters
    {yml_file_path, _} = filters |> Map.pop("pipeline_file", "")

    Ratio.data(
      project_id,
      branch_name,
      yml_file_path,
      org_id,
      user_id,
      from,
      to,
      tracing_headers
    )
  end

  # credo:disable-for-next-line
  def fetch(
        {:list_pipelines, {filters, name}},
        dashboard,
        index,
        _user_id,
        _org_id,
        page,
        page_size,
        from,
        to,
        tracing_headers
      ) do
    Logger.info(inspect(name))
    Logger.info(inspect(filters))

    {project_id, branch_name, filters} = filters |> extract_filters
    {yml_file_path, _} = filters |> Map.pop("pipeline_file", "")

    {pipelines, pagination} =
      ListPipelines.data(
        project_id,
        branch_name,
        yml_file_path,
        page,
        page_size,
        from,
        to,
        tracing_headers
      )

    Logger.debug(fn -> "ListPipelines.data returned #{inspect(pipelines)}" end)

    path = "/dashboards/#{dashboard.id}/#{index}/poll"

    pagination =
      Front.Pagination.construct_links(
        path,
        pagination.current_page,
        pagination.total_pages
      )

    %{
      type: :list_pipelines,
      name: name,
      pipelines: pipelines,
      pagination: pagination,
      path: path,
      range: Date.range(from, to)
    }
  end

  defp extract_filters(filters) do
    {project_id, filters} = filters |> Map.pop("project_id", "")
    {branch_name, filters} = filters |> Map.pop("branch", "")

    {project_id, branch_name, filters}
  end

  defp map_filters(filters) do
    %{
      project_id: filters |> Map.get("project_id", ""),
      branch: filters |> Map.get("branch", ""),
      github_uid: filters |> Map.get("github_uid", ""),
      pipeline_file: filters |> Map.get("pipeline_file", ""),
      requester: false
    }
  end

  defp timestamp(_, nil), do: nil

  defp timestamp(:beginning, date) do
    case date |> Timex.to_datetime() do
      {:error, _} -> nil
      s -> s |> to_google_timestamp
    end
  end

  defp timestamp(:end, date) do
    if date == Timex.today() do
      ""
    else
      case date |> Timex.to_datetime() do
        {:error, _} -> nil
        s -> s |> Timex.end_of_day() |> to_google_timestamp
      end
    end
  end

  defp to_google_timestamp(date) do
    case Timex.to_unix(date) do
      {:error, _} -> nil
      s -> Google.Protobuf.Timestamp.new(seconds: s)
    end
  end

  defp git_ref_types(type) when is_nil(type) or type == "", do: []
  defp git_ref_types(_), do: ["branch"]
end
