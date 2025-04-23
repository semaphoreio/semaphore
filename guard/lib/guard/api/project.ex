defmodule Guard.Api.Project do
  require Logger

  @project_page_size 100

  def destroy_all_projects_by_org_id(""), do: {:error, "Invalid org_id"}

  def destroy_all_projects_by_org_id(org_id) do
    Watchman.benchmark("destroy_all_projects_by_org_id.duration", fn ->
      {:ok, channel} =
        GRPC.Stub.connect(Application.fetch_env!(:guard, :projecthub_grpc_endpoint))

      delete_all_projects_by_org_id(channel, org_id, 1, [])
    end)
  end

  defp delete_all_projects_by_org_id(channel, org_id, page, acc) do
    req = build_list_by_org_id_request(org_id, page)

    case InternalApi.Projecthub.ProjectService.Stub.list(channel, req, timeout: 30_000) do
      {:ok, response} when response.metadata.status.code == 0 ->
        projects = response.projects

        projects
        |> Enum.filter(fn project -> project.metadata.org_id == org_id end)
        |> Enum.map(fn project ->
          Task.async(fn ->
            delete_project(channel, project.metadata.id, org_id, project.metadata.owner_id)
          end)
        end)
        |> Enum.each(&Task.await(&1, 30_000))

        if length(projects) < @project_page_size do
          :ok
        else
          delete_all_projects_by_org_id(channel, org_id, page + 1, acc ++ projects)
        end

      _ ->
        message = "Failed to retrieve projects for org #{org_id}"
        Logger.error(message)
        {:error, message}
    end
  end

  def user_has_any_project?(user_id) do
    {:ok, channel} = GRPC.Stub.connect(Application.fetch_env!(:guard, :projecthub_grpc_endpoint))

    req = build_list_by_owner_id_request(user_id, 1)

    case InternalApi.Projecthub.ProjectService.Stub.list(channel, req, timeout: 30_000) do
      {:ok, response} when response.metadata.status.code == 0 ->
        response.projects |> length > 0

      _ ->
        false
    end
  end

  defp delete_project(channel, project_id, org_id, user_id) do
    req =
      InternalApi.Projecthub.DestroyRequest.new(
        id: project_id,
        metadata: InternalApi.Projecthub.RequestMeta.new(org_id: org_id, user_id: user_id)
      )

    case InternalApi.Projecthub.ProjectService.Stub.destroy(channel, req, timeout: 30_000) do
      {:ok, response} when response.metadata.status.code == 0 ->
        Logger.info("Deleted project with ID #{project_id}")
        :ok

      _ ->
        message = "Failed to delete project with ID #{project_id}"
        Logger.error(message)
        {:error, message}
    end
  end

  defp build_list_by_org_id_request(org_id, page),
    do: build_list_request(org_id: org_id, page: page)

  defp build_list_by_owner_id_request(owner_id, page),
    do: build_list_request(owner_id: owner_id, page: page)

  def build_list_request(opts) do
    InternalApi.Projecthub.ListRequest.new(
      metadata:
        InternalApi.Projecthub.RequestMeta.new(
          owner_id: opts[:owner_id] || "",
          org_id: opts[:org_id] || ""
        ),
      pagination:
        InternalApi.Projecthub.PaginationRequest.new(
          page: opts[:page] || 1,
          page_size: @project_page_size
        )
    )
  end
end
