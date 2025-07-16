# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
defmodule Front.Auth do
  @moduledoc false

  require Logger
  alias Front.RBAC.Permissions

  def public(conn, access) do
    cond do
      authorized?(conn, access) -> Plug.Conn.assign(conn, :authorization, :member)
      conn.assigns.project.public -> Plug.Conn.assign(conn, :authorization, :guest)
      true -> render404(conn)
    end
  end

  def private(conn, access) do
    if authorized?(conn, access) do
      Plug.Conn.assign(conn, :authorization, :member)
    else
      render404(conn)
    end
  end

  @doc """
  Checks if the user is authorized to perform any of the given operations.
  """
  @spec private_any(Plug.Conn.t(), [rights :: atom()]) :: Plug.Conn.t()
  def private_any(conn, access) do
    authorized? =
      Enum.reduce_while(access, false, fn access, acc ->
        is_authorized? = acc or authorized?(conn, access)
        if is_authorized?, do: {:halt, is_authorized?}, else: {:cont, is_authorized?}
      end)

    if authorized? do
      Plug.Conn.assign(conn, :authorization, :member)
    else
      render404(conn)
    end
  end

  @doc """
  Checks if the user is authorized to perform the given operation.
  """
  @spec can?(Plug.Conn.t(), atom()) :: boolean()
  def can?(conn, access), do: authorized?(conn, access)

  defp authorized?(conn, :read_organization) do
    read_organization?(
      conn.assigns.user_id,
      conn.assigns.organization_id,
      conn.assigns.tracing_headers
    )
  end

  defp authorized?(conn, operation)
       when operation in [
              :ViewWorkflow,
              :ViewJob,
              :ViewFlakyTests
            ] do
    Watchman.benchmark("auth-#{operation}.duration", fn ->
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id
      project_id = conn.assigns.project.id

      is_authorized?(org_id, user_id, %{name: :ViewProject, project_id: project_id})
    end)
  end

  defp authorized?(conn, operation)
       when operation in [
              :ViewProject,
              :ViewProjectScheduler,
              :ViewProjectSettings
            ] do
    Watchman.benchmark("auth-#{operation}.duration", fn ->
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id
      project_id = conn.assigns.project.id

      is_authorized?(org_id, user_id, %{name: operation, project_id: project_id})
    end)
  end

  defp authorized?(conn, operation)
       when operation in [
              :ManageProjectScheduler,
              :ManageProjectSettings,
              :ManageProjectSecrets,
              :DeleteProject
            ] do
    Watchman.benchmark("auth-#{operation}.duration", fn ->
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id
      project_id = conn.assigns.project.id

      is_authorized?(org_id, user_id, %{name: operation, project_id: project_id})
    end)
  end

  defp authorized?(conn, operation)
       when operation in [
              :ViewOrganizationSettings
            ] do
    Watchman.benchmark("auth-#{operation}.duration", fn ->
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      is_authorized?(org_id, user_id, %{name: operation})
    end)
  end

  defp authorized?(conn, operation)
       when operation in [
              :ViewBilling
            ] do
    Watchman.benchmark("auth-#{operation}.duration", fn ->
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      is_authorized?(org_id, user_id, %{name: operation})
    end)
  end

  defp authorized?(conn, operation) do
    Watchman.benchmark("auth-#{operation}.duration", fn ->
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      is_authorized?(org_id, user_id, %{name: operation})
    end)
  end

  def update_project?(user_id, project_id, org_id, _metadata \\ nil) do
    Permissions.has?(user_id, org_id, project_id, "project.general_settings.manage")
  end

  def delete_project?(user_id, project_id, org_id, _metadata \\ nil) do
    Permissions.has?(user_id, org_id, project_id, "project.delete")
  end

  def read_organization?(user_id, org_id, _metadata \\ nil) do
    Permissions.has?(user_id, org_id, "organization.view")
  end

  def manage_people?(user_id, org_id, _metadata \\ nil) do
    Permissions.has?(user_id, org_id, "organization.people.manage")
  end

  def is_billing_admin?(org_id, user_id, _metadata \\ nil) do
    Permissions.has?(user_id, org_id, "insider.billing.view")
  rescue
    e ->
      Logger.error("is_billing_admin? failed: #{inspect(e)}")
      false
  end

  def refresh_people(org_id) do
    req = InternalApi.RBAC.RefreshCollaboratorsRequest.new(org_id: org_id)

    Logger.debug("Refresh Request")
    Logger.debug(inspect(req))

    {:ok, channel} = GRPC.Stub.connect(Application.fetch_env!(:front, :rbac_grpc_endpoint))

    {:ok, res} = InternalApi.RBAC.RBAC.Stub.refresh_collaborators(channel, req, timeout: 30_000)

    Logger.debug("Received refresh response")
    Logger.debug(inspect(res))

    {:ok, true}
  end

  def is_authorized?(org_id, user_id, operation) when is_atom(operation) do
    is_authorized?(org_id, user_id, %{name: operation})
  end

  def is_authorized?(org_id, user_id, operation) when not is_list(operation) do
    is_authorized?(org_id, user_id, [operation])
    |> Map.values()
    |> List.first()
  end

  def is_authorized?(org_id, user_id, operations) do
    {project_based_operations, org_based_operations} =
      Enum.split_with(operations, &Map.has_key?(&1, :project_id))

    has_permissions =
      Enum.reduce([project_based_operations, org_based_operations], %{}, fn operations, acc ->
        if operations == [] do
          acc
        else
          permissions = Enum.map(operations, &operation_to_permission(&1))
          project_id = Map.get(List.first(operations), :project_id, "")

          Map.merge(acc, Permissions.has?(user_id, org_id, project_id, permissions))
        end
      end)

    Enum.reduce(has_permissions, %{}, fn {key, value}, acc ->
      atom_key = permission_to_operation(key)
      Map.put(acc, atom_key, value)
    end)
  end

  defp operation_to_permission(operation) do
    case operation.name do
      :ViewOrganizationSettings ->
        "organization.general_settings.view"

      :ViewProjectSettings ->
        "project.general_settings.view"

      :AddProject ->
        "organization.projects.create"

      :DeleteProject ->
        "project.delete"

      :ManagePeople ->
        case Map.get(operation, :project_id, "") do
          "" -> "organization.people.manage"
          _ -> "project.access.manage"
        end

      :ManageSecrets ->
        "organization.secrets.manage"

      :ViewSecrets ->
        "organization.secrets.view"

      :ManageSecretsPolicySettings ->
        "organization.secrets_policy_settings.manage"

      :ViewSecretsPolicySettings ->
        "organization.secrets_policy_settings.view"

      :ManageProjectSettings ->
        "project.general_settings.manage"

      :ManageOrganizationSettings ->
        "organization.general_settings.manage"

      :ViewProjectScheduler ->
        "project.scheduler.view"

      :ManageProjectScheduler ->
        "project.scheduler.manage"

      :ViewProject ->
        "project.view"

      :ViewSelfHostedAgentTypes ->
        "organization.self_hosted_agents.view"

      :ManageSelfHostedAgentTypes ->
        "organization.self_hosted_agents.manage"

      :ManageBilling ->
        "organization.plans_and_billing.manage"

      :ViewBilling ->
        "organization.plans_and_billing.view"

      :ViewOrganizationIpAllowList ->
        "organization.ip_allow_list.view"

      :ManageOrganizationIpAllowList ->
        "organization.ip_allow_list.manage"

      :ManageProjectSecrets ->
        "project.secrets.manage"

      :ViewDeploymentTargets ->
        "project.deployment_targets.view"

      :ManageDeploymentTargets ->
        "project.deployment_targets.manage"

      :ViewServiceAccounts ->
        "organization.service_accounts.view"

      :ManageServiceAccounts ->
        "organization.service_accounts.manage"

      _ ->
        Logger.error(
          "operation with name id #{inspect(operation)}, which is not supported in mapper"
        )

        "non-existing.permission"
    end
  end

  defp permission_to_operation(permission) do
    case permission do
      "organization.general_settings.view" -> :ViewOrganizationSettings
      "project.general_settings.view" -> :ViewProjectSettings
      "organization.projects.create" -> :AddProject
      "project.delete" -> :DeleteProject
      "organization.people.manage" -> :ManagePeople
      "project.access.manage" -> :ManagePeople
      "organization.secrets.manage" -> :ManageSecrets
      "organization.secrets.view" -> :ViewSecrets
      "organization.secrets_policy_settings.manage" -> :ManageSecretsPolicySettings
      "organization.secrets_policy_settings.view" -> :ViewSecretsPolicySettings
      "project.general_settings.manage" -> :ManageProjectSettings
      "organization.general_settings.manage" -> :ManageOrganizationSettings
      "project.scheduler.view" -> :ViewProjectScheduler
      "project.scheduler.manage" -> :ManageProjectScheduler
      "project.view" -> :ViewProject
      "organization.self_hosted_agents.view" -> :ViewSelfHostedAgentTypes
      "organization.self_hosted_agents.manage" -> :ManageSelfHostedAgentTypes
      "organization.plans_and_billing.manage" -> :ManageBilling
      "organization.plans_and_billing.view" -> :ViewBilling
      "organization.ip_allow_list.view" -> :ViewOrganizationIpAllowList
      "organization.ip_allow_list.manage" -> :ManageOrganizationIpAllowList
      "project.secrets.manage" -> :ManageProjectSecrets
      "project.deployment_targets.view" -> :ViewDeploymentTargets
      "project.deployment_targets.manage" -> :ManageDeploymentTargets
      "organization.service_accounts.view" -> :ViewServiceAccounts
      "organization.service_accounts.manage" -> :ManageServiceAccounts
      _ -> :unknown
    end
  end

  def render404(conn) do
    conn
    |> FrontWeb.PageController.status404(%{})
    |> Plug.Conn.halt()
  end
end
