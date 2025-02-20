defmodule Secrethub.ProjecthubClient do
  require Logger

  defmodule Project do
    defstruct [:id, :name, :org_id]

    def from_api(raw) do
      %__MODULE__{
        id: raw.metadata.id,
        name: raw.metadata.name,
        org_id: raw.metadata.org_id
      }
    end
  end

  def find_by_name(project_name, org_id, user_id) do
    Watchman.benchmark("secrethub.external.projecthub.describe", fn ->
      alias InternalApi.Projecthub.DescribeRequest, as: Request
      alias InternalApi.Projecthub.RequestMeta
      alias InternalApi.Projecthub.ProjectService.Stub

      req =
        Request.new(
          name: project_name,
          metadata: RequestMeta.new(org_id: org_id, user_id: user_id)
        )

      with {:ok, endpoint} <- Application.fetch_env(:secrethub, :projecthub_grpc_endpoint),
           {:ok, channel} <- GRPC.Stub.connect(endpoint),
           {:ok, res} <- Stub.describe(channel, req, timeout: 30_000) do
        if res.metadata.status.code == :OK do
          project = Project.from_api(res.project)
          {:ok, project}
        else
          {:error, :project_not_found}
        end
      else
        e ->
          Logger.info("Failed to fetch info for Project##{project_name}, #{inspect(e)}")

          {:error, :communication_error}
      end
    end)
  end

  def list(org_id) do
    Watchman.benchmark("list_projects.duration", fn ->
      list_(org_id)
    end)
  end

  defp list_(org_id, page \\ 1, projects \\ []) do
    alias InternalApi.Projecthub.ListRequest, as: Request
    alias InternalApi.Projecthub.RequestMeta
    alias InternalApi.Projecthub.PaginationRequest
    alias InternalApi.Projecthub.ProjectService.Stub

    req = RequestMeta.new(org_id: org_id)
    pagination = PaginationRequest.new(page: page, page_size: 300)

    list_request =
      Request.new(
        metadata: req,
        pagination: pagination
      )

    with {:ok, endpoint} <- Application.fetch_env(:secrethub, :projecthub_grpc_endpoint),
         {:ok, channel} <- GRPC.Stub.connect(endpoint) do
      {:ok, res} =
        Stub.list(
          channel,
          list_request,
          timeout: 30_000
        )

      more_projects = res.projects

      total_pages = res.pagination.total_pages

      if page < total_pages do
        list_(org_id, page + 1, projects ++ more_projects)
      else
        {projects ++ more_projects, total_pages}
      end
    end
  end
end
