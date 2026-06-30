defmodule Zebra.Apis.DebugPermissions do
  require Logger

  alias InternalApi.Projecthub.Project.Spec.PermissionType
  alias Zebra.Models.Job
  alias Zebra.Workers.JobRequestFactory.{Project, RepoProxy, Repository}

  def check_project(org_id, project, operation) do
    if restrictions_enabled?(org_id) do
      case check_project_permissions(
             nil,
             project.custom_permissions,
             permissions_list(operation, project),
             operation,
             nil
           ) do
        :ok -> {:ok, true}
        error -> error
      end
    else
      {:ok, true}
    end
  end

  def check(org_id, job, operation) do
    if restrictions_enabled?(org_id) do
      case check_org_permissions(job, operation) do
        :ok -> {:ok, true}
        error -> error
      end
    else
      {:ok, true}
    end
  end

  # Debug (SSH) and attach restrictions are gated by the `restrict_job_ssh_access`
  # feature. The feature is always present in the catalog, so a healthy lookup returns
  # `{:ok, feature}`. Any `{:error, _}` means the lookup itself failed (FeatureHub
  # unreachable, cold cache), so we fail closed — enforce restrictions rather than risk
  # granting unauthorized debug/attach — and log + count it.
  defp restrictions_enabled?(org_id) do
    case FeatureProvider.find_feature("restrict_job_ssh_access", param: org_id) do
      {:ok, feature} ->
        FeatureProvider.Feature.enabled?(feature)

      {:error, reason} ->
        Logger.warning(
          "restrict_job_ssh_access lookup failed for org #{org_id}; " <>
            "enforcing debug/attach restrictions (fail-closed): #{inspect(reason)}"
        )

        Watchman.increment("debug_permissions.feature_lookup_error")
        true
    end
  end

  defp check_org_permissions(job, operation) do
    job_type = Job.detect_type(job)

    with {:ok, hook_id} <- RepoProxy.extract_hook_id(job, job_type),
         find_repo_proxy <- Task.async(fn -> RepoProxy.find(hook_id) end),
         find_project <- Task.async(fn -> Project.find(job.project_id) end),
         {:ok, project} <- Task.await(find_project),
         find_repository <- Task.async(fn -> Repository.find(project.repository_id) end),
         {:ok, repo_proxy} <- Task.await(find_repo_proxy),
         {:ok, repository, _} <- Task.await(find_repository),
         permissions_list <- permissions_list(operation, project) do
      check_project_permissions(
        repo_proxy,
        project.custom_permissions,
        permissions_list,
        operation,
        repository
      )
    else
      e ->
        Logger.info("Error checking org permissions: #{inspect(e)}")
        {:error, :internal, "Error checking org permissions"}
    end
  end

  defp permissions_list(:debug, project), do: project.debug_permissions
  defp permissions_list(:debug_empty, project), do: project.debug_permissions
  defp permissions_list(:attach, project), do: project.attach_permissions

  defp check_project_permissions(repo_proxy, false, _, operation, repository) do
    check_project_permissions(repo_proxy, true, [], operation, repository)
  end

  defp check_project_permissions(_, true, permissions, :debug_empty, _) do
    check_permissions_for_empty_debug(permissions)
  end

  defp check_project_permissions(nil, true, permissions, _operation, _) do
    check_permissions_for_empty_debug(permissions)
  end

  defp check_project_permissions(repo_proxy, true, permissions, operation, repository) do
    case InternalApi.RepoProxy.Hook.Type.key(repo_proxy.git_ref_type) do
      :BRANCH ->
        check_permissions_for_branch(
          repo_proxy.branch_name,
          permissions,
          operation,
          repository.default_branch
        )

      :TAG ->
        check_permissions_for_tag(permissions, operation)

      :PR ->
        check_permissions_for_pr(repo_proxy.pr_slug, repo_proxy.repo_slug, permissions, operation)
    end
  end

  defp check_permissions_for_empty_debug(permissions) do
    Enum.member?(permissions, PermissionType.value(:EMPTY))
    |> permission_response("You are not allowed to debug this project")
  end

  defp check_permissions_for_branch(branch, permissions, operation, default_branch)
       when branch == default_branch do
    Enum.member?(permissions, PermissionType.value(:DEFAULT_BRANCH))
    |> permission_response(
      "You are not allowed to #{Atom.to_string(operation)} jobs on the default branch of this project"
    )
  end

  defp check_permissions_for_branch(_, permissions, operation, _) do
    Enum.member?(permissions, PermissionType.value(:NON_DEFAULT_BRANCH))
    |> permission_response(
      "You are not allowed to #{Atom.to_string(operation)} jobs on non default branches of this project"
    )
  end

  defp check_permissions_for_tag(permissions, operation) do
    Enum.member?(permissions, PermissionType.value(:TAG))
    |> permission_response(
      "You are not allowed to #{Atom.to_string(operation)} jobs on a tag of this project"
    )
  end

  defp check_permissions_for_pr(pr_slug, repo_slug, permissions, operation)
       when pr_slug == repo_slug do
    Enum.member?(permissions, PermissionType.value(:PULL_REQUEST))
    |> permission_response(
      "You are not allowed to #{Atom.to_string(operation)} jobs on a pull request of this project"
    )
  end

  defp check_permissions_for_pr(_, _, permissions, operation) do
    Enum.member?(permissions, PermissionType.value(:FORKED_PULL_REQUEST))
    |> permission_response(
      "You are not allowed to #{Atom.to_string(operation)} jobs on a forked pull request of this project"
    )
  end

  defp permission_response(true, _), do: :ok
  defp permission_response(false, message), do: {:error, :permission_denied, message}
end
