defmodule FrontWeb.Router do
  use FrontWeb, :router

  require Logger

  pipeline :browser do
    plug(Plug.RequestId)

    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(Plug.Parsers, parsers: [:urlencoded, :json], json_decoder: Poison)

    if Application.compile_env(:front, :environment) == :prod do
      plug(Plug.SSL,
        rewrite_on: [:x_forwarded_proto],
        expires: 63_072_000,
        subdomains: true,
        preload: true
      )

      plug(:put_secure_browser_headers, %{
        "cross-origin-resource-policy" => "same-site",
        "cross-origin-opener-policy" => "same-origin",
        "cross-origin-embedder-policy" => "credentialless"
      })
    else
      plug(:put_secure_browser_headers, %{
        "cross-origin-resource-policy" => "same-site",
        "cross-origin-opener-policy" => "same-origin"
        # Omit COEP in dev to allow Phoenix LiveReload iframe
      })
    end

    plug(:protect_from_forgery)

    plug(FrontWeb.Plug.ContentSecurityPolicy)

    if Enum.member?([:dev, :test], Application.compile_env(:front, :environment)) do
      plug(FrontWeb.Plug.DevelopmentHeaders)
    end

    plug(FrontWeb.Plug.AssignUserInfo)
    plug(FrontWeb.Plug.AssignOrgInfo)
    plug(FrontWeb.Plug.AssignBillingInfo)
    plug(FrontWeb.Plug.SentryContext)
    plug(FrontWeb.Plugs.LicenseVerifier)
    plug(Traceman.Plug.TraceHeaders)
    plug(Front.Tracing.TracingPlug)
    plug(FrontWeb.Plugs.CacheControl, :private_cache)
  end

  scope "/is_alive", FrontWeb do
    get("/", PageController, :is_alive)
  end

  scope Application.compile_env(:front, :me_path), FrontWeb,
    host: Application.compile_env(:front, :me_host) do
    pipe_through(:browser)

    get("/", MeController, :show)
    get("/permissions_initialized", MeController, :permissions_initialized)
    get("/github_app_installation", MeController, :github_app_installation)

    get("/account/welcome/okta", AccountController, :welcome_okta)

    get("/account", AccountController, :show)
    post("/account", AccountController, :update)
    post("/account/reset_token", AccountController, :reset_token)
    post("/account/reset_password", AccountController, :reset_password)
    post("/account/update_repo_scope/:provider", AccountController, :update_repo_scope)

    get("/sso/zendesk", SSOController, :zendesk)

    get("/new", OrganizationOnboardingController, :new, as: :organization_onboarding)
    post("/new", OrganizationOnboardingController, :create, as: :organization_onboarding)

    get("/wait", OrganizationOnboardingController, :wait_for_organization,
      as: :wait_for_organization
    )

    get("/*path", PageController, :status404)
  end

  scope "/", FrontWeb do
    pipe_through(:browser)

    post("/sidebar/star", SidebarController, :star)
    post("/sidebar/unstar", SidebarController, :unstar)

    get("/projects/:name_or_id/artifacts", ArtifactsController, :projects)
    get("/projects/:name_or_id/artifacts/:resource_path", ArtifactsController, :projects_download)
    delete("/projects/:name_or_id/artifacts", ArtifactsController, :projects_destroy)

    delete(
      "/projects/:name_or_id/artifacts/:resource_path",
      ArtifactsController,
      :projects_destroy
    )

    get("/workflows/:workflow_id/artifacts", ArtifactsController, :workflows)

    get(
      "/workflows/:workflow_id/artifacts/:resource_path",
      ArtifactsController,
      :workflows_download
    )

    delete("/workflows/:workflow_id/artifacts", ArtifactsController, :workflows_destroy)

    delete(
      "/workflows/:workflow_id/artifacts/:resource_path",
      ArtifactsController,
      :workflows_destroy
    )

    get("/settings", SettingsController, :show)

    get("/settings/change_url", SettingsController, :change_url)

    get("/settings/ip_allow_list", SettingsController, :ip_allow_list)

    post("/settings", SettingsController, :update)

    get("/settings/confirm_delete", SettingsController, :confirm_delete)

    delete("/settings", SettingsController, :destroy)

    get("/jwt_config", OrganizationJWTConfigController, :show)
    post("/jwt_config", OrganizationJWTConfigController, :update)

    get("/settings/git_integrations/*path", GitIntegrationController, :show)
    post("/settings/git_integrations/delete/*path", GitIntegrationController, :delete)
    post("/settings/git_integrations/edit/*path", GitIntegrationController, :update)

    get("/groups/:group_id/non_members.json", GroupsController, :fetch_group_non_members)
    get("/groups/:group_id/members.json", GroupsController, :fetch_group_members)
    get("/groups/:group_id/", GroupsController, :fetch_group)
    put("/groups/:group_id/", GroupsController, :modify_group)
    post("/groups", GroupsController, :create_group)
    delete("/groups/:group_id", GroupsController, :destroy_group)

    get("/roles", RolesController, :index)
    get("/roles/:scope/new", RolesController, :new)
    get("/roles/:role_id", RolesController, :show)
    get("/roles/:role_id/edit", RolesController, :edit)
    post("/roles", RolesController, :create)
    put("/roles/:role_id", RolesController, :update)
    delete("/roles/:role_id", RolesController, :delete)

    scope "/people" do
      get("/", PeopleController, :organization)
      post("/", PeopleController, :create)
      post("/refresh", PeopleController, :refresh)
      post("/assign_role", PeopleController, :assign_role)
      post("/retract_role", PeopleController, :retract_role)
      get("/render_members", PeopleController, :render_members)
      delete("/membership/:membership_id", PeopleController, :destroy, as: :remove_member)
      post("/create_member", PeopleController, :create_member)
      get("/create_member", Plugs.RedirectTo, to: "/sync")
      get("/sync", PeopleController, :sync)

      get("/:user_id", PeopleController, :show)
      post("/:user_id", PeopleController, :update)
      post("/:user_id/reset_token", PeopleController, :reset_token)
      post("/:user_id/reset_password", PeopleController, :reset_password)
      post("/:user_id/change_email", PeopleController, :change_email)
      post("/:user_id/update_repo_scope/:provider", PeopleController, :update_repo_scope)

      get("/offboarding/:user_id", OffboardingController, :show)
    end

    post("/project/:name_or_id/offboarding", OffboardingController, :transfer)
    delete("/project/:name_or_id/offboarding", OffboardingController, :remove)

    get("/projects", ProjectController, :index)

    get("/projects/:name_or_id", ProjectController, :show,
      assigns: %{
        filters: "branch,pr,tag",
        tab: :everything
      }
    )

    get("/projects/:name_or_id/branches", ProjectController, :show,
      assigns: %{filters: "branch", tab: :branch},
      as: :project_branches
    )

    get("/projects/:name_or_id/pull_requests", ProjectController, :show,
      assigns: %{filters: "pr", tab: :pr},
      as: :project_prs
    )

    get("/projects/:name_or_id/tags", ProjectController, :show,
      assigns: %{filters: "tag", tab: :tag},
      as: :project_tags
    )

    get("/projects/:name_or_id/branches/blocked", ProjectController, :blocked)
    get("/projects/:name_or_id/branches/filtered_blocked", ProjectController, :filtered_blocked)
    post("/projects/:name_or_id/build_blocked/:hook_id", ProjectController, :build_blocked)
    get("/projects/:name_or_id/workflows", ProjectController, :workflows)
    get("/projects/:name_or_id/queues", ProjectController, :queues)
    get("/projects/:name_or_id/filtered_branches", ProjectController, :filtered_branches)
    get("/projects/:name_or_id/filtered_new_owners", ProjectController, :filtered_new_owners)
    get("/projects/:name_or_id/people", PeopleController, :project)

    get(
      "/projects/:name_or_id/people/add_to_project",
      PeopleController,
      :fetch_project_non_members
    )

    scope("/projects/:name_or_id/insights", as: :insights) do
      scope("/metrics") do
        get("/:insight_type", Insights.MetricsController, :index)
      end

      get("/project_settings", Insights.MetricsController, :get_insights_project_settings)
      get("/available_dates", Insights.MetricsController, :available_metrics_dates)
      post("/project_settings", Insights.MetricsController, :update_insights_project_settings)

      scope("/dashboards") do
        get("/", Insights.DashboardsController, :index)
        post("/", Insights.DashboardsController, :create)
        put("/:dashboard_id", Insights.DashboardsController, :update)
        delete("/:dashboard_id", Insights.DashboardsController, :destroy)

        post("/:dashboard_id", Insights.DashboardsController, :create_item)
        put("/:dashboard_id/:item_id", Insights.DashboardsController, :update_item)
        get("/:dashboard_id/:item_id", Insights.DashboardsController, :show_item)

        put(
          "/:dashboard_id/:item_id/description",
          Insights.DashboardsController,
          :update_item_description
        )

        delete("/:dashboard_id/:item_id", Insights.DashboardsController, :destroy_item)
      end

      get("/*path", InsightsController, :index, as: :index)
    end

    scope("/projects/:name_or_id/flaky_tests", as: :flaky_tests) do
      get("/", FlakyTestsController, :index, as: :index)
      get("/flaky_list", FlakyTestsController, :flaky_tests, as: :flaky_list)
      get("/flaky_details", FlakyTestsController, :flaky_test_details, as: :details)
      get("/flaky_disruptions", FlakyTestsController, :flaky_test_disruptions, as: :disruptions)

      get("/disruption_history", FlakyTestsController, :disruption_history,
        as: :disruption_history
      )

      get("/flaky_history", FlakyTestsController, :flaky_history, as: :flaky_history)

      get("/filters", FlakyTestsController, :filters, as: :filters)
      post("/filters", FlakyTestsController, :create_filter, as: :create_filter)

      post("/filters/initialize", FlakyTestsController, :initialize_filters,
        as: :initialize_filters
      )

      get("/webhook_settings", FlakyTestsController, :webhook_settings, as: :webhook_settings)

      post("/webhook_settings", FlakyTestsController, :create_webhook_settings,
        as: :create_webhook_settings
      )

      put("/webhook_settings", FlakyTestsController, :update_webhook_settings,
        as: :update_webhook_settings
      )

      delete("/webhook_settings", FlakyTestsController, :delete_webhook_settings,
        as: :delete_webhook_settings
      )

      put("/filters", FlakyTestsController, :update_filter, as: :update_filter)
      delete("/filters", FlakyTestsController, :remove_filter, as: :remove_filter)

      post("/:test_id/labels", FlakyTestsController, :add_label, as: :add_label)
      delete("/:test_id/labels/:label", FlakyTestsController, :remove_label, as: :remove_label)

      post("/:test_id/resolve", FlakyTestsController, :resolve, as: :resolve)
      post("/:test_id/undo_resolve", FlakyTestsController, :undo_resolve, as: :undo_resolve)

      post("/:test_id/ticket", FlakyTestsController, :save_ticket_url, as: :save_ticket_url)

      get("/*path", FlakyTestsController, :index, as: :index)
    end

    get("/projects/:name_or_id/check_workflow", ProjectController, :check_workflow)

    get("/projects/:name_or_id/edit_workflow", ProjectController, :edit_workflow)

    post("/projects/:name_or_id/commit_config", ProjectController, :commit_config)

    get("/projects/:name_or_id/check_commit_job", ProjectController, :check_commit_job)
    get("/projects/:name_or_id/fetch_yaml_artifacts", ProjectController, :fetch_yaml_artifacts)

    # Project Onboarding
    get("/new_project", ProjectOnboardingController, :new)

    # old choose_repository
    get("/choose_repository", ProjectOnboardingController, :choose_repository,
      assigns: %{integration_type: :github_oauth_token},
      as: :github_legacy_choose_repository
    )

    get("/github/choose_repository", ProjectOnboardingController, :choose_repository,
      assigns: %{integration_type: :github_app},
      as: :github_choose_repository
    )

    get("/bitbucket/choose_repository", ProjectOnboardingController, :choose_repository,
      assigns: %{integration_type: :bitbucket},
      as: :bitbucket_choose_repository
    )

    scope "/x" do
      get("/new_project", ProjectOnboardingController, :index)

      get("/new_project/github_app", ProjectOnboardingController, :index,
        assigns: %{integration_type: :github_app},
        as: :github_choose_repository
      )

      get("/new_project/github_oauth_token", ProjectOnboardingController, :index,
        assigns: %{integration_type: :github_oauth_token},
        as: :github_legacy_choose_repository
      )

      get("/new_project/bitbucket", ProjectOnboardingController, :index,
        assigns: %{integration_type: :bitbucket},
        as: :bitbucket_choose_repository
      )

      get("/new_project/gitlab", ProjectOnboardingController, :index,
        assigns: %{integration_type: :gitlab},
        as: :gitlab_choose_repository
      )

      post("/new_project/check_duplicates", ProjectOnboardingController, :check_duplicates)
      get("/new_project/*other", ProjectOnboardingController, :index)

      post("/projects", ProjectOnboardingController, :create)
      get("/repositories", ProjectOnboardingController, :repositories)

      post(
        "/projects/:name_or_id/skip_onboarding",
        ProjectOnboardingController,
        :skip_onboarding
      )

      get("/projects/:name_or_id/onboarding", ProjectOnboardingController, :onboarding_index)

      get(
        "/projects/:name_or_id/onboarding/*stage",
        ProjectOnboardingController,
        :onboarding_index
      )

      post(
        "/projects/:name_or_id/workflow_builder",
        ProjectOnboardingController,
        :x_workflow_builder,
        as: :x_workflow_builder
      )

      get("/projects/:name_or_id/is_ready", ProjectOnboardingController, :is_ready)

      post(
        "/projects/:name_or_id/regenerate_webhook_secret",
        ProjectOnboardingController,
        :regenerate_webhook_secret
      )

      put(
        "/projects/:name_or_id/onboarding/set_initial_yaml",
        ProjectOnboardingController,
        :update_project_initial_pipeline_file
      )
    end

    post("/projects", ProjectOnboardingController, :create)

    get(
      "/projects/:name_or_id/repository_status",
      ProjectOnboardingController,
      :project_repository_status
    )

    post(
      "/projects/:name_or_id/commit_starter_template",
      ProjectOnboardingController,
      :commit_starter_template
    )

    get("/projects/:name_or_id/initializing", ProjectOnboardingController, :initializing)

    get("/repositories", ProjectOnboardingController, :repositories)

    get("/projects/:name_or_id/is_ready", ProjectOnboardingController, :is_ready)

    get(
      "/projects/:name_or_id/invite_collaborators",
      ProjectOnboardingController,
      :invite_collaborators
    )

    post("/projects/:name_or_id/send_invitations", ProjectOnboardingController, :send_invitations)

    get(
      "/projects/:name_or_id/existing_configuration",
      ProjectOnboardingController,
      :existing_configuration
    )

    get("/projects/:name_or_id/template", ProjectOnboardingController, :template)

    get("/projects/:name_or_id/workflow_builder", ProjectOnboardingController, :workflow_builder)

    post("/fork/:provider/:repository_name", ProjectForkController, :fork)
    get("/fork/:provider/:repository_name/auth", ProjectForkController, :after_auth)
    get("/fork/:repository_name/initializing/:fork_uuid", ProjectForkController, :initializing)
    get("/fork/:fork_uuid/is_ready", ProjectForkController, :is_ready)

    get("/projects/:name_or_id/settings/general", ProjectSettingsController, :general)
    put("/projects/:name_or_id/settings", ProjectSettingsController, :update)
    get("/projects/:name_or_id/settings/delete", ProjectSettingsController, :confirm_delete)
    post("/projects/:name_or_id/settings/delete", ProjectSettingsController, :submit_delete)

    get("/projects/:name_or_id/settings/repository", ProjectSettingsController, :repository)

    post(
      "/projects/:name_or_id/settings/github/switch",
      ProjectSettingsController,
      :github_switch
    )

    get("/projects/:name_or_id/settings/notifications", ProjectSettingsController, :notifications)
    get("/projects/:name_or_id/settings/workflow", ProjectSettingsController, :workflow)
    get("/projects/:name_or_id/settings/badge", ProjectSettingsController, :badge)

    get(
      "/projects/:name_or_id/settings/debug_sessions",
      ProjectSettingsController,
      :debug_sessions
    )

    get(
      "/projects/:name_or_id/settings/permissions",
      ProjectSettingsController,
      :permissions
    )

    put(
      "/projects/:name_or_id/settings/debug_sessions",
      ProjectSettingsController,
      :update_debug_sessions
    )

    post("/projects/:name_or_id/settings/make_public", ProjectSettingsController, :make_public)
    post("/projects/:name_or_id/settings/make_private", ProjectSettingsController, :make_private)
    post("/projects/:name_or_id/settings/change_owner", ProjectSettingsController, :change_owner)

    post(
      "/projects/:name_or_id/settings/regenerate_deploy_key",
      ProjectSettingsController,
      :regenerate_deploy_key
    )

    post(
      "/projects/:name_or_id/settings/regenerate_webhook",
      ProjectSettingsController,
      :regenerate_webhook
    )

    get("/projects/:name_or_id/settings/artifacts", ProjectSettingsController, :artifacts)

    put(
      "/projects/:name_or_id/settings/artifacts",
      ProjectSettingsController,
      :update_artifact_settings
    )

    get("/projects/:name_or_id/settings/scheduler", ProjectSettingsController, :scheduler)

    get("/projects/:name_or_id/settings/secrets", ProjectSettings.SecretsController, :index)

    get(
      "/projects/:name_or_id/settings/secrets.json",
      ProjectSettings.SecretsController,
      :org_secrets
    )

    get("/projects/:name_or_id/settings/secrets/new", ProjectSettings.SecretsController, :new)

    get(
      "/projects/:name_or_id/settings/secrets/:id/edit",
      ProjectSettings.SecretsController,
      :edit
    )

    post("/projects/:name_or_id/settings/secrets", ProjectSettings.SecretsController, :create)
    put("/projects/:name_or_id/settings/secrets/:id", ProjectSettings.SecretsController, :update)

    delete(
      "/projects/:name_or_id/settings/secrets/:id",
      ProjectSettings.SecretsController,
      :delete
    )

    get("/projects/:name_or_id/schedulers", SchedulersController, :index)
    get("/projects/:name_or_id/schedulers/new", SchedulersController, :new)
    get("/projects/:name_or_id/schedulers/expression", SchedulersController, :expression)
    post("/projects/:name_or_id/schedulers/new", SchedulersController, :create)
    get("/projects/:name_or_id/schedulers/:id/edit", SchedulersController, :edit)
    get("/projects/:name_or_id/schedulers/:id", SchedulersController, :show)
    put("/projects/:name_or_id/schedulers/:id", SchedulersController, :update)
    delete("/projects/:name_or_id/schedulers/:id", SchedulersController, :destroy)
    post("/projects/:name_or_id/schedulers/:id/activate", SchedulersController, :activate)
    post("/projects/:name_or_id/schedulers/:id/deactivate", SchedulersController, :deactivate)
    get("/projects/:name_or_id/schedulers/:id/just_run", SchedulersController, :form_just_run)
    post("/projects/:name_or_id/schedulers/:id/just_run", SchedulersController, :trigger_just_run)
    get("/projects/:name_or_id/schedulers/:id/history", SchedulersController, :history)
    get("/projects/:name_or_id/schedulers/:id/latest", SchedulersController, :latest)

    get("/projects/:name_or_id/deployments", DeploymentsController, :index)
    get("/projects/:name_or_id/deployments/new", DeploymentsController, :new)
    get("/projects/:name_or_id/deployments/:id/edit", DeploymentsController, :edit)
    get("/projects/:name_or_id/deployments/:id", DeploymentsController, :show)
    put("/projects/:name_or_id/deployments/:id/cordon/:state", DeploymentsController, :cordon)
    post("/projects/:name_or_id/deployments", DeploymentsController, :create)
    put("/projects/:name_or_id/deployments/:id", DeploymentsController, :update)
    delete("/projects/:name_or_id/deployments/:id", DeploymentsController, :delete)

    post("/projects/scopes/github", RepositoryScopesController, :github, as: :github_update_scope)

    post("/projects/scopes/github_app", RepositoryScopesController, :github_app,
      as: :github_app_update_scope
    )

    post("/projects/scopes/bitbucket", RepositoryScopesController, :bitbucket,
      as: :bitbucket_update_scope
    )

    post("/projects/scopes/gitlab", RepositoryScopesController, :gitlab, as: :gitlab_update_scope)

    get("/projects/:name_or_id/settings/pre_flight_checks", ProjectPFCController, :show)
    put("/projects/:name_or_id/settings/pre_flight_checks", ProjectPFCController, :put)
    delete("/projects/:name_or_id/settings/pre_flight_checks", ProjectPFCController, :delete)

    get("/projects/:name_or_id/report", ReportController, :project)

    get("/", DashboardController, :index)
    get("/workflows", DashboardController, :workflows)
    get("/dashboards/:name", DashboardController, :show)
    get("/dashboards/:id/:index/poll", DashboardController, :poll)
    get("/dashboards/:id/:index/chart", DashboardController, :chart)

    get("/secrets", SecretsController, :index)
    get("/secrets.json", SecretsController, :secrets)
    get("/secrets/new", SecretsController, :new)
    post("/secrets", SecretsController, :create)
    get("/secrets/:id/edit", SecretsController, :edit)
    put("/secrets/:id", SecretsController, :update)
    delete("/secrets/:id", SecretsController, :delete)

    post("/notifications/new", NotificationsController, :create)

    get("/notifications/new", NotificationsController, :new)

    get("/notifications", NotificationsController, :index)

    get("/notifications/:id/edit", NotificationsController, :edit)

    delete("/notifications/:id", NotificationsController, :destroy)
    put("/notifications/:id", NotificationsController, :update)

    get("/init_job_defaults", OrganizationPFCController, :show)
    get("/pre_flight_checks", OrganizationPFCController, :show)
    put("/pre_flight_checks", OrganizationPFCController, :put_pre_flight_checks)
    delete("/pre_flight_checks", OrganizationPFCController, :delete)
    put("/init_job_defaults", OrganizationPFCController, :put_init_job_defaults)

    # Okta Integration Settings
    get("/settings/okta", OrganizationOktaController, :show)
    get("/settings/okta/form", OrganizationOktaController, :form)
    get("/settings/okta/group_mapping", OrganizationOktaController, :group_mapping)
    post("/settings/okta/group_mapping", OrganizationOktaController, :update_group_mapping)

    get(
      "/settings/okta/disconnect_notice/:integration_id",
      OrganizationOktaController,
      :disconnect_notice
    )

    post(
      "/settings/okta/disconnect/:integration_id",
      OrganizationOktaController,
      :disconnect
    )

    post("/settings/okta", OrganizationOktaController, :create)

    # Organization Contacts Settings
    get("/settings/contacts", OrganizationContactsController, :show)
    post("/settings/contacts", OrganizationContactsController, :modify)

    # Branch Page
    get("/branches/:branch_id", BranchController, :show)

    get("/branches/:branch_id/poll", BranchController, :workflows)
    get("/branches/:branch_id/workflows", BranchController, :workflows)

    get("/branches/:branch_id/edit_workflow", BranchController, :edit_workflow)

    # Workflow Editor
    get("/workflows/:workflow_id/edit", WorkflowController, :edit)

    # Workflow Page
    get("/workflows/:workflow_id", WorkflowController, :show)

    get("/workflows/:workflow_id/status", WorkflowController, :status)
    get("/workflows/:workflow_id/summary", TestResultsController, :pipeline_summary)
    get("/workflows/:workflow_id/report", ReportController, :workflow)
    get("/workflows/:workflow_id/summary/:pipeline_id", TestResultsController, :details)
    get("/workflows/:workflow_id/pipelines/:pipeline_id", PipelineController, :show)
    get("/workflows/:workflow_id/pipelines/:pipeline_id/poll", PipelineController, :poll)
    get("/workflows/:workflow_id/pipelines/:pipeline_id/path", PipelineController, :path)
    get("/workflows/:workflow_id/pipelines/:pipeline_id/status", PipelineController, :status)

    get(
      "/workflows/:workflow_id/pipelines/:pipeline_id/switches/:switch_id",
      PipelineController,
      :switch
    )

    post("/workflows/:workflow_id/rebuild", WorkflowController, :rebuild)

    post("/workflows/:workflow_id/pipelines/:pipeline_id/stop", PipelineController, :stop,
      as: :pipeline_stop
    )

    post("/workflows/:workflow_id/pipelines/:pipeline_id/rebuild", PipelineController, :rebuild,
      as: :pipeline_rebuild
    )

    post(
      "/workflows/:workflow_id/pipelines/:pipeline_id/swithes/:switch_id/targets/:name",
      TargetController,
      :trigger
    )

    # Job Page
    scope "/jobs/:id" do
      get("/", JobController, :show)
      get("/status", JobController, :status)
      get("/status_badge", JobController, :status_badge)
      get("/summary", TestResultsController, :job_summary)
      get("/logs", JobController, :logs)
      get("/report", ReportController, :job)

      get("/edit_workflow", JobController, :edit_workflow)

      post("/stop", JobController, :stop)

      get("/raw_logs.json", JobController, :events)

      get("/events.json", JobController, :events)

      get("/plain_logs.txt", JobController, :plain_logs)

      # Deprecated, left here for backwards compatibility.
      get("/plain_logs.json", JobController, :plain_logs)

      get("/artifacts", ArtifactsController, :jobs)
      get("/artifacts/:resource_path", ArtifactsController, :jobs_download)
      delete("/artifacts", ArtifactsController, :jobs_destroy)
      delete("/artifacts/:resource_path", ArtifactsController, :jobs_destroy)
    end

    # Support Page
    get("/support", SupportController, :new)

    post("/support", SupportController, :submit)
    get("/support/thanks", SupportController, :thanks)

    # Activity Monitor
    get("/activity", ActivityMonitorController, :index)
    get("/activity/data", ActivityMonitorController, :activity_data)
    post("/activity/stop", ActivityMonitorController, :stop)

    # Audit
    get("/audit", AuditController, :index)
    get("/audit/csv", AuditController, :csv)
    get("/audit/streaming", AuditController, :show)

    get("/audit/streaming/setup", AuditController, :setup)
    post("/audit/streaming/setup", AuditController, :test_connection)
    # used to pause/activate
    post("/audit/streaming/status", AuditController, :status)
    post("/audit/streaming/create", AuditController, :create)
    post("/audit/streaming/update", AuditController, :update)
    delete("/audit/streaming/setup", AuditController, :delete)

    resources("/self_hosted_agents", SelfHostedAgentController) do
      get("/edit", SelfHostedAgentController, :edit, as: :edit)

      get("/agents", SelfHostedAgentController, :agents)

      post("/agents/:agent_name/disable", SelfHostedAgentController, :disable_agent,
        as: :disable_agent
      )

      post("/reset_token", SelfHostedAgentController, :reset_token, as: :reset_token)

      post("/disable_all_agents", SelfHostedAgentController, :disable_all_agents,
        as: :disable_all_agents
      )

      get("/confirm_delete", SelfHostedAgentController, :confirm_delete, as: :confirm_delete)

      get("/confirm_reset_token", SelfHostedAgentController, :confirm_reset_token,
        as: :confirm_reset_token
      )

      get("/confirm_disable_all", SelfHostedAgentController, :confirm_disable_all,
        as: :confirm_disable_all
      )

      get("/confirm_disable/:agent_name", SelfHostedAgentController, :confirm_disable,
        as: :confirm_disable
      )
    end

    scope "/agents", as: :agents do
      get("/", AgentsController, :index, as: :index)
      get("/*path", AgentsController, :index, as: :index)
    end

    scope "/billing", as: :billing do
      get("/spending.csv", BillingController, :spending_csv, as: :spending_csv)
      get("/projects.csv", BillingController, :projects_csv, as: :projects_csv)
      get("/invoices.json", BillingController, :invoices, as: :invoices)
      get("/seats.json", BillingController, :seats, as: :seats)
      get("/costs.json", BillingController, :costs, as: :costs)
      post("/budget.json", BillingController, :set_budget, as: :budget)
      get("/budget.json", BillingController, :get_budget, as: :budget)
      get("/credits.json", BillingController, :credits, as: :credits)
      get("/can_upgrade.json", BillingController, :can_upgrade, as: :can_upgrade)

      post("/upgrade.json", BillingController, :upgrade, as: :upgrade)

      post("/acknowledge_plan_change.json", BillingController, :acknowledge_plan_change,
        as: :acknowledge_plan_change
      )

      get("/project.json", BillingController, :project, as: :project)
      get("/projects.json", BillingController, :projects, as: :projects)
      get("/top_projects.json", BillingController, :top_projects, as: :top_projects)

      get("/*path", BillingController, :index, as: :index)
    end

    scope "/get_started", as: :get_started do
      post("/signal", GetStartedController, :signal, as: :signal)
      get("/*path", GetStartedController, :index, as: :index)
    end

    scope "/organization_health", as: :organization_health do
      get("/", OrganizationHealthController, :index, as: :index)
    end

    get("/*path", PageController, :status404)
  end
end
