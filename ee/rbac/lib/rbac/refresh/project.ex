defmodule Rbac.Refresh.Project do
  require Logger

  def refresh(ids) do
    Task.async(fn ->
      Enum.each(ids, fn id -> refresh_one(id) end)
    end)
  end

  def refresh_one(project_id) do
    with :ok <- check_last_refresh(project_id),
         {:ok, project} <- Rbac.Models.Project.find(project_id) do
      update_and_refresh(project)
    else
      :error ->
        Logger.info("Project ##{project_id} was updated recently - skipping")
        :ok

      _ ->
        Logger.info("Project ##{project_id} not found")
        :ok
    end
  end

  def check_last_refresh(project_id) do
    case Rbac.Store.Project.find(project_id) do
      {:ok, %{updated_at: updated_at}} ->
        #
        # GitHub limits how many requests we can make per hour, and this action
        # can breach this limit for organizations with a significant number
        # of projects and collaborators.
        #
        t_65_minutes_ago = DateTime.utc_now() |> DateTime.add(-3_900, :second)
        updated_at = DateTime.from_naive!(updated_at, "Etc/UTC")

        case DateTime.compare(t_65_minutes_ago, updated_at) do
          :lt -> :error
          _ -> :ok
        end

      _ ->
        :ok
    end
  end

  defp update_and_refresh(project) do
    {:ok, p} =
      Rbac.Store.Project.update(
        project.id,
        project.repository.full_name,
        project.org_id,
        project.repository.provider,
        project.repository.id
      )

    case Rbac.CollaboratorsRefresher.refresh(p) do
      :ok ->
        Rbac.Store.Project.touch_update_at(project.id)
        :ok

      error ->
        error
    end
  rescue
    e -> Sentry.capture_exception(e, extra: %{project_id: project.id})
  end
end
