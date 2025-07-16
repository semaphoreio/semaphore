defmodule FrontWeb.Plugs.OrganizationAuthorization do
  alias FrontWeb.ActivityMonitorController, as: ActivityMonitor
  alias FrontWeb.AuditController, as: Audit
  alias FrontWeb.BillingController, as: Billing
  alias FrontWeb.DashboardController, as: Dashboard
  alias FrontWeb.NotificationsController, as: Notification
  alias FrontWeb.OrganizationContactsController, as: OrganizationContacts
  alias FrontWeb.OrganizationHealthController, as: OrganizationHealth
  alias FrontWeb.OrganizationOktaController, as: Okta
  alias FrontWeb.OrganizationPFCController, as: PreFlightChecks
  alias FrontWeb.PeopleController, as: People
  alias FrontWeb.ProjectController, as: Project
  alias FrontWeb.ProjectForkController, as: ProjectFork
  alias FrontWeb.ProjectOnboardingController, as: ProjectOnboarding
  alias FrontWeb.RegistriesController, as: Registries
  alias FrontWeb.RepositoryScopesController, as: Repository
  alias FrontWeb.SchedulersController, as: Schedulers
  alias FrontWeb.SecretsController, as: Secrets
  alias FrontWeb.SelfHostedAgentController, as: SelfHostedAgent
  alias FrontWeb.SettingsController, as: Settings
  alias FrontWeb.SupportController, as: Support
  alias FrontWeb.ServiceAccountController, as: ServiceAccount

  alias Front.Auth

  def init(default), do: default

  def call(conn, _) do
    conn
    |> authorize
  end

  defp authorize(conn) do
    authorize(conn.private.phoenix_controller, conn.private.phoenix_action, conn)
  end

  defp authorize(Project, _, conn), do: Auth.private(conn, :read_organization)
  defp authorize(ProjectOnboarding, _, conn), do: Auth.private(conn, :AddProject)
  defp authorize(ProjectFork, _, conn), do: Auth.private(conn, :AddProject)
  defp authorize(Notification, _, conn), do: can?(conn, "organization.view")
  defp authorize(Repository, _, conn), do: Auth.private(conn, :read_organization)
  defp authorize(Secrets, _, conn), do: can?(conn, "organization.view")

  defp authorize(Settings, _, conn), do: can?(conn, "organization.view")
  defp authorize(Support, _, conn), do: Auth.private(conn, :read_organization)
  defp authorize(Registries, _, conn), do: Auth.private(conn, :read_organization)
  defp authorize(Dashboard, _, conn), do: Auth.private(conn, :read_organization)
  defp authorize(ActivityMonitor, _, conn), do: Auth.private(conn, :read_organization)
  defp authorize(People, _, conn), do: Auth.private(conn, :read_organization)
  defp authorize(Schedulers, _, conn), do: Auth.private(conn, :read_organization)
  defp authorize(NewTestResults, _, conn), do: Auth.private(conn, :read_organization)
  defp authorize(OrganizationHealth, _, conn), do: Auth.private(conn, :read_organization)

  defp authorize(OrganizationContacts, _, conn),
    do: Auth.private(conn, :read_organization)

  defp authorize(SelfHostedAgent, :index, conn), do: Auth.private(conn, :ViewSelfHostedAgentTypes)
  defp authorize(SelfHostedAgent, :new, conn), do: Auth.private(conn, :ManageSelfHostedAgentTypes)

  defp authorize(SelfHostedAgent, :create, conn),
    do: Auth.private(conn, :ManageSelfHostedAgentTypes)

  defp authorize(SelfHostedAgent, :show, conn),
    do: Auth.private(conn, :ManageSelfHostedAgentTypes)

  defp authorize(SelfHostedAgent, :edit, conn),
    do: Auth.private(conn, :ManageSelfHostedAgentTypes)

  defp authorize(SelfHostedAgent, :update, conn),
    do: Auth.private(conn, :ManageSelfHostedAgentTypes)

  defp authorize(SelfHostedAgent, :agents, conn),
    do: Auth.private(conn, :ManageSelfHostedAgentTypes)

  defp authorize(SelfHostedAgent, :confirm_delete, conn),
    do: Auth.private(conn, :ManageSelfHostedAgentTypes)

  defp authorize(SelfHostedAgent, :confirm_disable, conn),
    do: Auth.private(conn, :ManageSelfHostedAgentTypes)

  defp authorize(SelfHostedAgent, :confirm_reset_token, conn),
    do: Auth.private(conn, :ManageSelfHostedAgentTypes)

  defp authorize(SelfHostedAgent, :confirm_disable_all, conn),
    do: Auth.private(conn, :ManageSelfHostedAgentTypes)

  defp authorize(SelfHostedAgent, :delete, conn),
    do: Auth.private(conn, :ManageSelfHostedAgentTypes)

  defp authorize(SelfHostedAgent, :disable_agent, conn),
    do: Auth.private(conn, :ManageSelfHostedAgentTypes)

  defp authorize(SelfHostedAgent, :disable_all_agents, conn),
    do: Auth.private(conn, :ManageSelfHostedAgentTypes)

  defp authorize(SelfHostedAgent, :reset_token, conn),
    do: Auth.private(conn, :ManageSelfHostedAgentTypes)

  defp authorize(PreFlightChecks, :show, conn),
    do: Auth.private(conn, :ViewOrganizationSettings)

  defp authorize(PreFlightChecks, :put, conn),
    do: Auth.private(conn, :ManageOrganizationSettings)

  defp authorize(PreFlightChecks, :delete, conn),
    do: Auth.private(conn, :ManageOrganizationSettings)

  defp authorize(Okta, :show, conn), do: Auth.private(conn, :ViewOrganizationSettings)
  defp authorize(Okta, _, conn), do: Auth.private(conn, :ManageOrganizationSettings)

  defp authorize(Audit, :index, conn), do: Auth.private(conn, :read_organization)
  defp authorize(Audit, :show, conn), do: Auth.private(conn, :ViewOrganizationSettings)
  defp authorize(Audit, _, conn), do: Auth.private(conn, :ManageOrganizationSettings)

  defp authorize(Billing, :index, conn),
    do: Auth.private_any(conn, [:ViewBilling, :ViewOrganizationSettings])

  defp authorize(Billing, :upgrade, conn), do: Auth.private(conn, :ManageBilling)
  defp authorize(Billing, :set_budget, conn), do: Auth.private(conn, :ManageBilling)
  defp authorize(Billing, :invoices, conn), do: Auth.private(conn, :ManageBilling)
  defp authorize(Billing, _, conn), do: Auth.private(conn, :ViewBilling)

  defp authorize(ServiceAccount, action, conn)
       when action in [:create, :update, :delete, :regenerate_token],
       do: Auth.private(conn, :ManageServiceAccounts)

  defp authorize(ServiceAccount, _, conn), do: Auth.private(conn, :ViewServiceAccounts)

  defp can?(conn, permission) do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id

    if Front.RBAC.Permissions.has?(user_id, org_id, permission) do
      Plug.Conn.assign(conn, :authorization, :member)
    else
      render404(conn)
    end
  end

  defp render404(conn) do
    conn
    |> FrontWeb.PageController.status404(%{})
    |> Plug.Conn.halt()
  end
end
