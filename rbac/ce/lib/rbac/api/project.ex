defmodule Rbac.Api.Project do
  require Logger
  alias InternalApi.Projecthub

  @project_page_size 100

  def list_by_org_id(org_id) do
    endpoint = Application.get_env(:rbac, :projecthub_grpc_endpoint)

    with {:ok, channel} <- GRPC.Stub.connect(endpoint),
         {:ok, projects} <- do_list_by_org_id(channel, org_id, 1, []) do
      {:ok, projects}
    else
      {:error, message} ->
        Logger.error(message)
        {:error, message}
    end
  end

  defp do_list_by_org_id(channel, org_id, page, acc) do
    req = build_list_by_org_id_request(org_id, page)

    case Projecthub.ProjectService.Stub.list(channel, req, timeout: 30_000) do
      {:ok, response} when response.metadata.status.code == :OK ->
        projects = response.projects

        if length(projects) < @project_page_size do
          {:ok, acc ++ projects}
        else
          do_list_by_org_id(channel, org_id, page + 1, acc ++ projects)
        end

      _ ->
        message = "Failed to retrieve projects for org #{org_id}"
        {:error, message}
    end
  end

  defp build_list_by_org_id_request(org_id, page) do
    %Projecthub.ListRequest{
      metadata: %Projecthub.RequestMeta{org_id: org_id},
      pagination: %Projecthub.PaginationRequest{
        page: page,
        page_size: @project_page_size
      }
    }
  end
end
