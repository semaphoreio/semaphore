defmodule InternalClients.Dashboards.RequestFormatter do
  @moduledoc """
  Module serves to format data received from API client via HTTP into
  protobuf messages suitable for gRPC communication with Secrethub service.
  """

  require Logger

  alias InternalApi.Dashboardhub, as: API
  import InternalClients.Common

  # List keyset

  def form_request({API.ListRequest, params}) do
    {:ok,
     %API.ListRequest{
       metadata: metadata!(params),
       page_size: from_params(params, :page_size),
       page_token: from_params(params, :page_token)
     }}
  rescue
    error in ArgumentError ->
      {:error, {:user, error.message}}
  end

  def form_request({API.DescribeRequest, params}) do
    {:ok,
     %API.DescribeRequest{
       metadata: metadata!(params),
       id_or_name: from_params(params, :id_or_name)
     }}
  end

  def form_request({API.DestroyRequest, params}) do
    {:ok,
     %API.DestroyRequest{
       metadata: metadata!(params),
       id_or_name: from_params(params, :id_or_name)
     }}
  end

  def form_request({API.CreateRequest, params}) do
    metadata = metadata!(params)

    {:ok,
     %API.CreateRequest{
       metadata: metadata,
       dashboard: form_request({API.Dashboard, params, %{organization: %{id: metadata.org_id}}})
     }}
  rescue
    e in RuntimeError ->
      error = %{
        message: e.message,
        documentation_url: Application.get_env(:public_api, :documentation_url)
      }

      {:error, {:user, error}}
  end

  def form_request({API.UpdateRequest, params}) do
    metadata = metadata!(params)

    {:ok,
     %API.UpdateRequest{
       metadata: metadata!(params),
       id_or_name: from_params(params, :id_or_name),
       dashboard: form_request({API.Dashboard, params, %{organization: %{id: metadata.org_id}}})
     }}
  end

  def form_request({API.Dashboard, params, ctx}) do
    %API.Dashboard{
      metadata: dashboard_metadata(params),
      spec: dashboard_spec(params, ctx)
    }
  end

  defp metadata!(params) do
    %API.RequestMeta{
      user_id: from_params!(params, :user_id),
      org_id: from_params!(params, :organization_id)
    }
  end

  defp dashboard_metadata(params) do
    %API.Dashboard.Metadata{
      name: from_params(params.metadata, :name),
      org_id: from_params!(params, :organization_id),
      title: from_params!(params.spec, :display_name)
    }
  end

  defp dashboard_spec(params, ctx) do
    %API.Dashboard.Spec{
      widgets: Enum.map(from_params!(params.spec, :widgets), &widget(&1, ctx))
    }
  end

  defp widget(params, ctx) do
    %API.Dashboard.Spec.Widget{
      name: from_params!(params, :name),
      type: from_params!(params, :type) |> map_type(),
      filters: filters(params.filters, ctx)
    }
  end

  defp map_type("WORKFLOWS"), do: "list_workflows"
  defp map_type("PIPELINES"), do: "list_pipelines"

  defp filters(filters, ctx) do
    %{
      "pipeline_file" => filters |> Map.get(:pipeline_file, ""),
      "branch" => filters |> Map.get(:reference, "") |> String.replace_prefix("refs/heads/", ""),
      "project_id" => map_project(filters, ctx)
    }
  end

  defp map_project(%{project: %{id: id}}, ctx) when is_binary(id) and id != "" do
    case InternalClients.Projecthub.describe(%{organization_id: ctx.organization.id, id: id}) do
      {:ok, project} ->
        project.metadata.id

      {:error, _} ->
        Logger.error("Project #{id} in organization #{ctx.organization.id} not found")
        raise "Project #{id} not found"
    end
  end

  defp map_project(%{project: %{name: name}}, ctx) when is_binary(name) and name != "" do
    case InternalClients.Projecthub.describe(%{organization_id: ctx.organization.id, name: name}) do
      {:ok, project} ->
        project.metadata.id

      {:error, _} ->
        Logger.error("Project #{name} in organization #{ctx.organization.id} not found")
        raise "Project #{name} not found"
    end
  end

  defp map_project(_, _), do: ""
end
