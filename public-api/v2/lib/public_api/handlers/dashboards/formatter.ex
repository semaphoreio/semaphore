defmodule PublicAPI.Handlers.Dashboards.Formatter do
  @moduledoc false
  alias InternalApi.Dashboardhub, as: API

  require Logger

  def describe(dashboard = %API.Dashboard{}, ctx) do
    projects =
      dashboard
      |> extract_projects()
      |> map_projects(ctx)

    ctx = ctx |> Map.put(:projects, projects)

    {:ok, dashboard_from_pb(dashboard, ctx)}
  end

  def list(%{entries: dashboards, next_page_token: next, page_size: size}, ctx) do
    projects =
      dashboards
      |> extract_projects()
      |> map_projects(ctx)

    ctx = ctx |> Map.put(:projects, projects)

    {:ok,
     %{
       next_page_token: next,
       page_size: size,
       entries: Enum.map(dashboards, fn dashboard -> dashboard_from_pb(dashboard, ctx) end)
     }}
  end

  defp extract_projects(dashboards) when is_list(dashboards) do
    dashboards
    |> Enum.map(&extract_projects/1)
    |> List.flatten()
  end

  defp extract_projects(%{spec: %{widgets: widgets}}) do
    Enum.map(widgets, fn widget -> widget.filters["project_id"] end)
    |> Enum.filter(&(is_binary(&1) and &1 != ""))
    |> Enum.uniq()
  end

  defp map_projects([], _), do: %{}

  defp map_projects(project_ids, ctx) do
    case InternalClients.Projecthub.describe_many(%{
           organization_id: ctx.organization.id,
           project_ids: project_ids
         }) do
      {:ok, projects} ->
        project_ids
        |> Enum.map(&separate_project(&1, projects))
        |> Enum.reject(&is_nil/1)
        |> Map.new()

      {:error, e} ->
        Logger.error("Error fetching projects: #{inspect(e)}")
        raise "Project not found"
    end
  end

  defp separate_project(project_id, projects) do
    Enum.find_value(projects, fn project ->
      if project.metadata.id == project_id,
        do: {project_id, %{id: project_id, name: project.metadata.name}}
    end)
  end

  defp dashboard_from_pb(%API.Dashboard{spec: spec, metadata: metadata}, ctx) do
    organization = %{id: metadata.org_id, name: ctx.organization.name}

    %{
      apiVersion: "v2",
      kind: "Dashboard",
      metadata: %{
        id: metadata.id,
        name: metadata.name,
        organization: organization,
        timeline: %{
          created_at: PublicAPI.Util.Timestamps.to_timestamp(metadata.create_time),
          created_by: nil,
          updated_at: PublicAPI.Util.Timestamps.to_timestamp(metadata.update_time),
          updated_by: nil
        }
      },
      spec: %{
        display_name: metadata.title,
        widgets: Enum.map(spec.widgets, fn widget -> widget_from_pb(widget, ctx) end)
      }
    }
  end

  defp widget_from_pb(widget = %API.Dashboard.Spec.Widget{}, ctx) do
    %{
      name: widget.name,
      type: map_type(widget.type),
      filters: filters_from_pb(widget.filters, ctx)
    }
  end

  defp map_type("list_workflows"), do: "WORKFLOWS"
  defp map_type("list_pipelines"), do: "PIPELINES"

  defp filters_from_pb(filters, ctx) do
    %{}
    |> maybe_put_reference(filters["branch"])
    |> maybe_put_pipeline_file(filters["pipeline_file"])
    |> maybe_put_project(filters["project_id"], ctx)
  end

  defp maybe_put_reference(filters, branch) when is_binary(branch) and branch != "" do
    Map.put(filters, :reference, "refs/heads/#{branch}")
  end

  defp maybe_put_reference(filters, _), do: filters

  defp maybe_put_pipeline_file(filters, pipeline_file)
       when is_binary(pipeline_file) and pipeline_file != "" do
    Map.put(filters, :pipeline_file, pipeline_file)
  end

  defp maybe_put_pipeline_file(filters, _), do: filters

  defp maybe_put_project(filters, project_id, ctx)
       when is_binary(project_id) and project_id != "" do
    case Map.fetch(ctx.projects, project_id) do
      {:ok, project} ->
        Map.put(filters, :project, project)

      :error ->
        if ctx.allow_all_projects do
          Map.put(filters, :project, %{id: project_id, name: nil})
        else
          raise "Project not found"
        end
    end
  end

  defp maybe_put_project(filters, _, _), do: filters
end
