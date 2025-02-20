defmodule Rbac.Refresh.Organization do
  require Logger

  def refresh(ids) do
    if Application.get_env(:rbac, :ignore_refresh_requests) do
      :ok
    else
      Enum.each(ids, fn id -> refresh_one(id) end)
    end
  end

  defp refresh_one(org_id) do
    alias Rbac.Repo.CollaboratorRefreshRequest, as: Request

    {:ok, project_ids} = Rbac.Store.Project.list_projects(org_id)

    {:ok, request} = Request.new(org_id, project_ids, nil) |> Rbac.Repo.insert()

    Rbac.Refresh.Worker.perform_now(request.id)
  end
end
