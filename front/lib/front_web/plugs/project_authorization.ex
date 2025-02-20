defmodule FrontWeb.Plugs.ProjectAuthorization do
  import Plug.Conn

  alias Front.Auth
  alias Front.Models.{Project, User}
  alias FrontWeb.ArtifactsController, as: A
  alias FrontWeb.DeploymentsController, as: DT
  alias FrontWeb.FlakyTestsController, as: FTC
  alias FrontWeb.Insights.DashboardsController, as: DSH
  alias FrontWeb.Insights.MetricsController, as: IM
  alias FrontWeb.InsightsController, as: InsightsController
  alias FrontWeb.OffboardingController, as: O
  alias FrontWeb.PeopleController, as: Pe
  alias FrontWeb.ProjectController, as: P
  alias FrontWeb.ProjectOnboardingController, as: PO
  alias FrontWeb.ProjectPeopleController, as: Ppc
  alias FrontWeb.ProjectPFCController, as: PFC
  alias FrontWeb.ProjectSettings.SecretsController, as: PSecret
  alias FrontWeb.ProjectSettingsController, as: PS
  alias FrontWeb.SchedulersController, as: S

  def init(default), do: default

  def call(conn, _) do
    conn
    |> fetch_project
    |> authorize
  end

  defp fetch_project(conn) do
    project_id = conn.params["name_or_id"]
    org_id = conn.assigns.organization_id

    case Project.find(project_id, org_id) do
      nil -> conn |> assign(:project, nil) |> Auth.render404()
      project -> assign(conn, :project, project)
    end
  end

  defp fetch_user(conn) do
    case conn.assigns.anonymous do
      true ->
        conn
        |> assign(:user_id, "")
        |> assign(:user, nil)

      false ->
        conn |> assign(:user, User.find(conn.assigns.user_id))
    end
  end

  defp authorize(conn) do
    if conn.assigns.project == nil do
      conn
    else
      authorize(conn.private.phoenix_controller, conn.private.phoenix_action, conn)
    end
  end

  defp authorize(A, :projects, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(A, :projects_download, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(A, :projects_destroy, conn), do: Auth.private(conn, :ViewProject)

  defp authorize(P, :show, conn), do: Auth.public(conn |> fetch_user(), :ViewProject)
  defp authorize(P, :commit_config, conn), do: Auth.private(conn, :ViewProject)
  # 404 js if no project
  defp authorize(P, :check_setup, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(P, :check_workflow, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(P, :edit_workflow, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(P, :workflows, conn), do: Auth.public(conn, :ViewProject)
  defp authorize(P, :queues, conn), do: Auth.public(conn, :ViewProject)
  defp authorize(P, :filtered_branches, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(P, :filtered_new_owners, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(P, :blocked, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(P, :filtered_blocked, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(P, :build_blocked, conn), do: Auth.private(conn, :ViewProject)

  defp authorize(Pe, :project, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(Pe, :fetch_project_non_members, conn), do: Auth.private(conn, :ViewProject)

  defp authorize(Ppc, :new, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(Ppc, :create, conn), do: Auth.private(conn, :ManageProjectSettings)

  defp authorize(PS, :general, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(PS, :repository, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(PS, :notifications, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(PS, :workflow, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(PS, :badge, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(PS, :permissions, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(PS, :artifacts, conn), do: Auth.private(conn, :ViewProject)

  defp authorize(PS, :update_artifact_settings, conn),
    do: Auth.private(conn, :ManageProjectSettings)

  defp authorize(PS, :debug_sessions, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(PS, :update, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(PS, :update_debug_sessions, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(PS, :confirm_delete, conn), do: Auth.private(conn, :DeleteProject)
  defp authorize(PS, :submit_delete, conn), do: Auth.private(conn, :DeleteProject)
  defp authorize(PS, :make_public, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(PS, :make_private, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(PS, :change_owner, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(PS, :regenerate_deploy_key, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(PS, :regenerate_webhook, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(PS, :github_switch, conn), do: Auth.private(conn, :ManageProjectSettings)

  defp authorize(PO, :new, conn), do: Auth.private(conn, :AddProject)
  defp authorize(PO, :initializing, conn), do: Auth.private(conn, :AddProject)
  defp authorize(PO, :is_ready, conn), do: Auth.private(conn, :AddProject)
  defp authorize(PO, :invite_collaborators, conn), do: Auth.private(conn, :AddProject)
  defp authorize(PO, :send_invitations, conn), do: Auth.private(conn, :AddProject)
  defp authorize(PO, :commit_starter_template, conn), do: Auth.private(conn, :AddProject)
  defp authorize(PO, :template, conn), do: Auth.private(conn, :AddProject)
  defp authorize(PO, :existing_configuration, conn), do: Auth.private(conn, :AddProject)
  defp authorize(PO, :workflow_builder, conn), do: Auth.private(conn, :AddProject)
  defp authorize(PO, :x_workflow_builder, conn), do: Auth.private(conn, :AddProject)
  defp authorize(PO, :onboarding_index, conn), do: Auth.private(conn, :AddProject)
  defp authorize(PO, :skip_onboarding, conn), do: Auth.private(conn, :AddProject)

  defp authorize(PO, :update_project_initial_pipeline_file, conn),
    do: Auth.private(conn, :ManageProjectSettings)

  defp authorize(S, :index, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(S, :latest, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(S, :expression, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(S, :show, conn), do: Auth.private(conn, :ViewProjectScheduler)
  defp authorize(S, :history, conn), do: Auth.private(conn, :ViewProjectScheduler)
  defp authorize(S, :form_just_run, conn), do: Auth.private(conn, :ViewProjectScheduler)
  defp authorize(S, :trigger_just_run, conn), do: Auth.private(conn, :ViewProjectScheduler)
  defp authorize(S, _, conn), do: Auth.private(conn, :ManageProjectScheduler)

  defp authorize(O, _, conn), do: Auth.private(conn, :ManagePeople)

  defp authorize(InsightsController, :index, conn), do: Auth.private(conn, :ViewProject)

  # need to have its own :authorization
  defp authorize(IM, :index, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(IM, :get_insights_project_settings, conn), do: Auth.private(conn, :ViewProject)

  defp authorize(IM, :update_insights_project_settings, conn),
    do: Auth.private(conn, :ViewProject)

  defp authorize(IM, :available_metrics_dates, conn), do: Auth.private(conn, :ViewProject)

  defp authorize(DSH, :index, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(DSH, :create, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(DSH, :update, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(DSH, :destroy, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(DSH, :show_item, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(DSH, :create_item, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(DSH, :update_item, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(DSH, :destroy_item, conn), do: Auth.private(conn, :ManageProjectSettings)

  defp authorize(PFC, :show, conn), do: Auth.private(conn, :ViewProjectSettings)
  defp authorize(PFC, :put, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(PFC, :delete, conn), do: Auth.private(conn, :ManageProjectSettings)

  defp authorize(DT, :index, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(DT, :show, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(DT, :new, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(DT, :edit, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(DT, :cordon, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(DT, :create, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(DT, :update, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(DT, :delete, conn), do: Auth.private(conn, :ManageProjectSettings)

  defp authorize(PSecret, :index, conn), do: Auth.private(conn, :ManageProjectSecrets)
  defp authorize(PSecret, :org_secrets, conn), do: Auth.private(conn, :ManageProjectSecrets)
  defp authorize(PSecret, :new, conn), do: Auth.private(conn, :ManageProjectSecrets)
  defp authorize(PSecret, :edit, conn), do: Auth.private(conn, :ManageProjectSecrets)
  defp authorize(PSecret, :create, conn), do: Auth.private(conn, :ManageProjectSecrets)
  defp authorize(PSecret, :update, conn), do: Auth.private(conn, :ManageProjectSecrets)
  defp authorize(PSecret, :delete, conn), do: Auth.private(conn, :ManageProjectSecrets)

  # update with correct permission
  defp authorize(FTC, :index, conn), do: Auth.private(conn, :ViewFlakyTests)
  defp authorize(FTC, :flaky_tests, conn), do: Auth.private(conn, :ViewFlakyTests)
  defp authorize(FTC, :flaky_test_details, conn), do: Auth.private(conn, :ViewFlakyTests)
  defp authorize(FTC, :flaky_test_disruptions, conn), do: Auth.private(conn, :ViewFlakyTests)
  defp authorize(FTC, :flaky_history, conn), do: Auth.private(conn, :ViewFlakyTests)
  defp authorize(FTC, :disruption_history, conn), do: Auth.private(conn, :ViewFlakyTests)
  defp authorize(FTC, :filters, conn), do: Auth.private(conn, :ViewFlakyTests)
  defp authorize(FTC, :create_filter, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(FTC, :remove_filter, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(FTC, :update_filter, conn), do: Auth.private(conn, :ManageProjectSettings)
  defp authorize(FTC, :add_label, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(FTC, :remove_label, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(FTC, :resolve, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(FTC, :undo_resolve, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(FTC, :save_ticket_url, conn), do: Auth.private(conn, :ViewProject)
  defp authorize(FTC, :initialize_filters, conn), do: Auth.private(conn, :ViewFlakyTests)

  defp authorize(FTC, :webhook_settings, conn), do: Auth.private(conn, :ViewFlakyTests)

  defp authorize(FTC, :create_webhook_settings, conn),
    do: Auth.private(conn, :ManageProjectSettings)

  defp authorize(FTC, :update_webhook_settings, conn),
    do: Auth.private(conn, :ManageProjectSettings)

  defp authorize(FTC, :delete_webhook_settings, conn),
    do: Auth.private(conn, :ManageProjectSettings)
end
