defmodule Rbac.CollaboratorsRefresher do
  require Logger

  alias Rbac.{Store, Api}

  def refresh(project) do
    log(project.project_id, "Start")

    case Api.Repository.fetch_collaborators(project.repository_id) do
      {:ok, repository} ->
        {:ok, current} = Store.Project.collaborators_for_sync(project.project_id)

        (current -- repository) |> remove_collaborators(project.project_id, project.provider)
        (repository -- current) |> add_collaborators(project.project_id, project.provider)

        log(project.project_id, "End")

        :ok

      {:skip, message} ->
        log(project.project_id, "Skip: #{inspect(message)}")

        :ok

      error ->
        log(project.project_id, "Error: #{inspect(error)}")

        error
    end
  end

  defp remove_collaborators([], _, _), do: :ok

  defp remove_collaborators(collaborators, project_id, provider) do
    log(project_id, "Removing: #{inspect(Enum.map(collaborators, & &1["login"]))}")

    collaborators
    |> Enum.each(fn collaborator ->
      Store.Project.remove_collaborator(project_id, collaborator["id"])

      {:ok, project} = Store.Project.find(project_id)

      case collaborator["id"] |> Store.User.find_id_by_provider_uid(provider) do
        nil ->
          Rbac.Events.Authorization.publish(
            "collaborator_deleted",
            "",
            project.org_id,
            project_id
          )

        user_id ->
          Rbac.Events.Authorization.publish(
            "collaborator_deleted",
            user_id,
            project.org_id,
            project_id
          )

          # Syncing with RBAC
          source = String.to_atom(provider)

          Rbac.Repo.RbacRefreshProjectAccessRequest.add_request(
            project.org_id,
            user_id,
            project_id,
            :remove,
            source
          )
      end
    end)
  end

  defp add_collaborators([], _, _), do: :ok

  defp add_collaborators(collaborators, project_id, provider) do
    log(project_id, "Adding: #{inspect(Enum.map(collaborators, & &1["login"]))}")

    collaborators
    |> Enum.each(fn collaborator ->
      Store.Project.add_collaborator(project_id, collaborator)

      {:ok, project} = Store.Project.find(project_id)

      case collaborator["id"] |> Store.User.find_id_by_provider_uid(provider) do
        nil ->
          Rbac.Events.Authorization.publish(
            "collaborator_created",
            "",
            project.org_id,
            project_id
          )

        user_id ->
          Rbac.Events.Authorization.publish(
            "collaborator_created",
            user_id,
            project.org_id,
            project_id
          )

          # Syncing with RBAC
          source = String.to_atom(provider)

          role_to_be_assigned =
            Rbac.Repo.RepoToRoleMapping.get_project_role_from_repo_access_rights(
              project.org_id,
              collaborator["permissions"]["admin"],
              collaborator["permissions"]["push"],
              collaborator["permissions"]["pull"]
            )

          if role_to_be_assigned do
            Rbac.Repo.RbacRefreshProjectAccessRequest.add_request(
              project.org_id,
              user_id,
              project_id,
              :add,
              source,
              role_to_be_assigned
            )
          end
      end
    end)
  end

  defp log(project_id, message) do
    Logger.info("[Collaborators Refresher] #{project_id} - #{message}")
  end
end
