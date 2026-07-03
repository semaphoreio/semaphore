defmodule FrontWeb.ProjectOnboardingController do
  use FrontWeb, :controller
  require Logger

  alias Front.Async
  alias Front.Audit
  alias Front.Models
  alias Front.Clients

  plug(
    FrontWeb.Plugs.OnPremBlocker
    when action in [
           :invite_collaborators,
           :send_invitations
         ]
  )

  plug(
    FrontWeb.Plugs.ProjectAuthorization
    when action not in [
           :new,
           :choose_repository,
           :repositories,
           :refresh,
           :initializing,
           :index,
           :check_duplicates,
           :create,
           :project_repository_status,
           :repositories
         ]
  )

  plug(
    FrontWeb.Plugs.OrganizationAuthorization
    when action in [
           :new,
           :choose_repository,
           :repositories,
           :refresh,
           :initializing,
           # new_project_onboarding
           :index,
           :check_duplicates,
           :create,
           :project_repository_status,
           :repositories,
           :regenerate_webhook_secret
         ]
  )

  plug(
    FrontWeb.Plugs.Header
    when action in [
           :new,
           :choose_repository,
           :initializing,
           :invite_collaborators,
           :template,
           :existing_configuration,
           :workflow_builder,
           # new_project_onboarding
           :index,
           :check_duplicates,
           :create,
           :project_repository_status,
           :x_workflow_builder,
           :onboarding_index,
           :regenerate_webhook_secret,
           :skip_onboarding
         ]
  )

  @repository_integrator_instance_config_mapping %{
    GITHUB_APP: :CONFIG_TYPE_GITHUB_APP,
    GITHUB_OAUTH_TOKEN: :CONFIG_TYPE_GITHUB_APP,
    BITBUCKET: :CONFIG_TYPE_BITBUCKET_APP,
    GITLAB: :CONFIG_TYPE_GITLAB_APP,
    GIT: :CONFIG_TYPE_UNSPECIFIED
  }

  # Per-user cooldowns: 60s between targeted (single-repo) refreshes, 10 minutes
  # between full / per-organization refreshes.
  @targeted_refresh_cooldown_seconds 60
  @full_refresh_cooldown_seconds 600

  # A full/org refresh that fails for business reasons still ran the synchronous
  # org-push scan, so floor a short cooldown (rather than fully releasing) to
  # throttle a caller looping the same org against that scan.
  @full_refresh_failure_cooldown_seconds 60

  @repository_slug_format ~r|\A[A-Za-z0-9][A-Za-z0-9\-]{0,38}/[A-Za-z0-9._\-]{1,100}\z|
  @organization_format ~r/\A[A-Za-z0-9][A-Za-z0-9\-]{0,38}\z/

  # The UI surfaces the full-refresh cooldown (the org-refresh control).
  def refresh_cooldown_seconds, do: cooldown_seconds(:full)

  defp get_agent_name(project) do
    Front.Models.CommitJob.get_agent(project)
    |> case do
      {:ok, %{type: type}} ->
        type

      _ ->
        ""
    end
  end

  def regenerate_webhook_secret(conn, _params) do
    project = conn.assigns.project
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id

    %{id: project.id, metadata: %{org_id: org_id, user_id: user_id}}
    |> Clients.Projecthub.regenerate_webhook_secret()
    |> case do
      {:ok, response} ->
        Models.Project.check_webhook(project.id)
        |> case do
          {:ok, hook} ->
            conn
            |> json(%{
              message: "Webhook secret regenerated",
              secret: response.secret,
              endpoint: "#{hook.url}"
            })

          {:error, message} ->
            conn
            |> put_status(422)
            |> json(%{
              message: message,
              secret: response.secret,
              endpoint: ""
            })
        end

      {:error, error} ->
        conn
        |> put_status(422)
        |> json(%{
          error: error
        })
    end
  end

  def new(conn, params) do
    Watchman.benchmark("project.new.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id

      fetch_repository_integrators =
        Async.run(fn -> Models.Organization.repository_integrators(org_id) end)

      fetch_user = Async.run(fn -> Models.User.find(user_id) end)

      {:ok, user} = Async.await(fetch_user)
      {:ok, {:ok, repository_integrators}} = Async.await(fetch_repository_integrators)

      repositories = Models.Forkable.all()
      provider = Models.Forkable.map_integration_types(repository_integrators.primary)
      providers = Models.Forkable.map_integration_types(repository_integrators.enabled)

      conn
      |> render(
        "new.html",
        js: "new_project",
        repositories: repositories,
        provider: provider,
        providers: providers,
        user: user,
        choose_repository_path: org_choose_repository_path(conn),
        signup: params["signup"]
      )
    end)
  end

  def choose_repository(conn, params) do
    Watchman.benchmark("project.choose_repository.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id

      fetch_user = Async.run(fn -> Models.User.find(user_id) end)
      fetch_organization = Async.run(fn -> Models.Organization.find(org_id) end)

      fetch_repository_integrators =
        Async.run(fn -> Models.Organization.repository_integrators(org_id) end)

      {:ok, user} = Async.await(fetch_user)
      {:ok, organization} = Async.await(fetch_organization)
      {:ok, {:ok, repository_integrators}} = Async.await(fetch_repository_integrators)
      notice = params["notice"]

      case check_integration_type(conn, repository_integrators, conn.assigns.integration_type) do
        :ok ->
          conn
          |> put_layout(:project_onboarding)
          |> render("choose_repository.html",
            project_setup_phase: "Choose repository",
            user: user,
            sidebar_selected_item: nil,
            organization: organization,
            js: "repository",
            signup: params["signup"],
            notice: notice,
            title: "New Project・#{organization.name}",
            repositories_url:
              project_onboarding_path(conn, :repositories,
                integration_type: conn.assigns.integration_type
              ),
            repository_integrators: repository_integrators,
            bitbucket: show_bitbucket?(org_id)
          )

        redirect_path ->
          redirect(conn, to: redirect_path)
      end
    end)
  end

  @doc """
  First screen after the ProjectController.create action.

  It is a waiting screen that waits for all the project deps to
  be ready before moving on with the onboarding.

  When the waiting is done, the next screen is the template chooser.
  """
  def initializing(conn, params) do
    organization_id = conn.assigns.organization_id
    project = Models.Project.find(params["name_or_id"], organization_id)

    conn
    |> put_layout(:project_onboarding)
    |> render("initializing.html",
      js: "projectOnboardingInitializing",
      project_setup_phase: "Choose repository",
      project_name_or_id: params["name_or_id"],
      project: project,
      check_url: project_onboarding_path(conn, :is_ready, project.name),
      title: "Initializing・#{project.name}"
    )
  end

  def invite_collaborators(conn, _params) do
    project = conn.assigns.project
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id

    fetch_user = Async.run(fn -> Models.User.find(user_id) end)

    fetch_collaborators =
      Async.run(fn ->
        Models.Member.repository_collaborators(org_id, project.id)
      end)

    {:ok, user} = Async.await(fetch_user)
    {:ok, {:ok, collaborators}} = Async.await(fetch_collaborators)

    next_page_href =
      if Models.Project.file_exists?(project.id, project.initial_pipeline_file) do
        project_onboarding_path(conn, :existing_configuration, project.name)
      else
        project_onboarding_path(conn, :template, project.name)
      end

    if Enum.empty?(collaborators) do
      conn
      |> put_layout(:project_onboarding)
      |> render("invite_collaborators_empty_slate.html",
        title: "Add people・#{project.name}",
        project_setup_phase: "Add people",
        user: user,
        next_page_href: next_page_href,
        project: project
      )
    else
      conn
      |> put_layout(:project_onboarding)
      |> render("invite_collaborators.html",
        title: "Add people・#{project.name}",
        js: "inviteProjectPeople",
        project_setup_phase: "Add people",
        user: user,
        collaborators: collaborators,
        next_page_href: next_page_href,
        project: project
      )
    end
  end

  def send_invitations(conn, params) do
    user_id = conn.assigns.user_id
    organization_id = conn.assigns.organization_id
    invitation_list = params["invitation_list"]

    conn
    |> Audit.new(:User, :Added)
    |> Audit.add(description: "Adding members to the organization")
    |> Audit.add(resource_name: inspect(invitation_list))
    |> Audit.log()

    {:ok, _members} = Models.Member.invite(invitation_list, organization_id, user_id)

    conn |> json("ok")
  end

  def existing_configuration(conn, _params) do
    project = conn.assigns.project

    conn
    |> put_layout(:project_onboarding)
    |> render("existing_configuration.html",
      project_setup_phase: "Set up workflow",
      project_name_or_id: conn.params["name_or_id"],
      project: project,
      title: "Configuration already exists・#{project.name}"
    )
  end

  def template(conn, _params) do
    project = conn.assigns.project

    conn
    |> put_layout(:project_onboarding)
    |> render("template.html",
      project_setup_phase: "Set up workflow",
      project_name_or_id: conn.params["name_or_id"],
      templates: Front.Templates.load_all(),
      title: "Choose starter template・#{project.name}",
      js: "templatePicker"
    )
  end

  # to keep from old code

  def create(conn, params) do
    Watchman.benchmark("project.create.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id

      audit =
        conn
        |> Audit.new(:Project, :Added)
        |> Audit.add(description: "Added a new project")
        |> Audit.metadata(url: params["url"])
        |> Audit.log()

      with {:ok, []} <- check_duplicates(org_id, params["url"], params["duplicate"]),
           {:ok, project} <-
             Models.Project.create(
               org_id,
               user_id,
               params["name"],
               params["url"],
               params["integration_type"]
             ) do
        audit
        |> Audit.add(resource_id: project.id)
        |> Audit.add(resource_name: project.name)
        |> Audit.log()

        if FeatureProvider.feature_enabled?(:new_project_onboarding, param: org_id) do
          conn
          |> json(%{
            check_url: project_onboarding_path(conn, :is_ready, project.name),
            repo_connection_url:
              project_onboarding_path(conn, :project_repository_status, project.name),
            project_name: project.name,
            skip_project_onboarding_url:
              project_onboarding_path(conn, :skip_onboarding, project.name)
          })
        else
          conn
          |> json(%{redirect_to: project_onboarding_path(conn, :initializing, project.name)})
        end
      else
        {:ok, projects} ->
          projects =
            projects
            |> Enum.map(fn project ->
              %{name: project.name, path: project_path(conn, :show, project.name)}
            end)

          conn
          |> json(%{projects: projects})

        {:error, message} ->
          conn
          |> put_status(200)
          |> json(%{
            error: normalize_project_creation_error(message)
          })
      end
    end)
  end

  # new_project_onboarding

  def index(conn, _params) do
    Watchman.benchmark("project.new.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id

      fetch_user = Async.run(fn -> Models.User.find(user_id) end)

      fetch_repository_integrators =
        Async.run(fn -> Models.Organization.repository_integrators(org_id) end)

      {:ok, user} = Async.await(fetch_user)

      {:ok, {:ok, repository_integrators}} = Async.await(fetch_repository_integrators)

      fetch_instance_configs =
        Async.run(fn ->
          if FeatureProvider.feature_enabled?("instance_git_integration", param: org_id) do
            Logger.debug("Fetching integrations")

            integrators =
              repository_integrators.enabled
              |> Enum.map(fn integrator_type ->
                {atomize_integration_type(integrator_type),
                 Map.get(
                   @repository_integrator_instance_config_mapping,
                   atomize_integration_type(integrator_type)
                 )}
              end)
              |> Enum.reject(fn {_, config_type} -> config_type == :CONFIG_TYPE_UNSPECIFIED end)
              |> Enum.uniq()

            Logger.debug("integrators: #{inspect(integrators)}")

            {:ok, instance_configs} =
              integrators
              |> Enum.map(&elem(&1, 1))
              |> Models.InstanceConfig.list_integrations()

            {:ok,
             integrators
             |> Enum.reduce(%{}, fn {integration_type, instance_config_key}, acc ->
               Map.put(
                 acc,
                 integration_type,
                 Enum.find(instance_configs, &(&1.type == instance_config_key))
               )
             end)}
          else
            Logger.debug("Integration setup is disabled")
            {:ok, []}
          end
        end)

      {:ok, {:ok, instance_configs}} = Async.await(fetch_instance_configs)

      conn
      |> render(
        "x_new.html",
        js: "index_new_project",
        org_id: org_id,
        user: user,
        primary_provider: repository_integrators.primary |> atomize_integration_type(),
        providers:
          repository_integrators.enabled
          |> Enum.map(&atomize_integration_type/1)
          |> maybe_filter_bitbucket(org_id),
        instance_configs: instance_configs,
        project_setup_phase: "Select project type"
      )
    end)
  end

  def check_duplicates(conn, params) do
    org_id = conn.assigns.organization_id
    url = params["url"]
    Logger.debug("checking duplicates for #{url}")

    case check_duplicates(org_id, url, "false") do
      {:ok, []} ->
        Logger.debug("No duplicates found")
        conn |> json(%{duplicate: false})

      {:ok, projects} ->
        Logger.debug("duplicates found")

        projects =
          Enum.map(projects, fn project ->
            %{name: project.name, path: project_path(conn, :show, project.name)}
          end)

        iteration_names = projects |> Enum.map(& &1.name)

        next_iteration_name =
          1..50
          |> Enum.find(50, fn n ->
            candidate = Front.Sufix.with_sufix(params["name"], n)
            candidate not in iteration_names
          end)
          |> then(&Front.Sufix.with_sufix(params["name"], &1))

        conn
        |> json(%{projects: projects, next_iteration_name: next_iteration_name})

      {:error, message} ->
        Logger.debug("Error checking duplicates: #{message}")

        conn
        |> json(%{error: normalize_project_creation_error(message)})
    end
  end

  defp normalize_project_creation_error(message) when message in ["", nil],
    do: "Project creation failed"

  defp normalize_project_creation_error(message), do: message

  defp check_duplicates(_org_id, _url, "true"), do: {:ok, []}
  defp check_duplicates(org_id, url, _), do: Models.Project.list_by_repo_url(org_id, url)

  def repositories(conn, params) do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id

    page_token = params |> Map.get("page_token", "")
    integration_type = params |> Map.get("integration_type", "github_oauth_token")

    fetch_organization = Async.run(fn -> Models.Organization.find(org_id) end)
    {:ok, organization} = Async.await(fetch_organization)

    case Models.Repository.list_repositories(
           user_id,
           integration_type,
           page_token,
           organization.open_source
         ) do
      {:ok, repositories} ->
        json(conn, repositories)

      {:error, error_response} ->
        conn
        |> put_status(:service_unavailable)
        |> json(error_response)
    end
  end

  @doc """
  Re-syncs the cached GitHub App repository list: full refresh without a
  "repository_slug" (cooldown-limited), or a single repo with one. Non-github_app
  types are fetched live, so they no-op.
  """
  def refresh(conn, params) do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id
    integration_type = Map.get(params, "integration_type", "")
    slug = params |> Map.get("repository_slug", "") |> String.trim()
    organization = params |> Map.get("organization", "") |> String.trim()

    cond do
      integration_type != "github_app" ->
        json(conn, %{
          state: "done",
          message: "This repository list is always fetched live from the provider."
        })

      slug != "" and not Regex.match?(@repository_slug_format, slug) ->
        conn
        |> put_status(422)
        |> json(%{state: "failed", message: "Use the owner/repository format."})

      slug != "" ->
        start_targeted_refresh(conn, user_id, org_id, slug)

      organization != "" and not Regex.match?(@organization_format, organization) ->
        conn
        |> put_status(422)
        |> json(%{state: "failed", message: "Use a valid GitHub organization name."})

      true ->
        start_full_refresh(conn, user_id, org_id, organization)
    end
  end

  # Full / per-organization refresh, throttled per (user, GitHub org) so
  # refreshing one org doesn't block a different one.
  defp start_full_refresh(conn, user_id, org_id, organization) do
    case claim_refresh_cooldown(:full, org_id, user_id, cooldown_resource(:full, organization)) do
      :ok -> do_refresh(conn, user_id, :full, "", organization)
      {:cooldown, seconds_left} -> rate_limited(conn, seconds_left)
    end
  end

  # Targeted refresh, throttled per user (not per slug, on purpose: the cooldown
  # is kept on failure so a caller cannot loop denied slugs to spam the
  # synchronous push check).
  defp start_targeted_refresh(conn, user_id, org_id, slug) do
    case claim_refresh_cooldown(:targeted, org_id, user_id, cooldown_resource(:targeted, "")) do
      :ok -> do_refresh(conn, user_id, :targeted, slug, "")
      {:cooldown, seconds_left} -> rate_limited(conn, seconds_left)
    end
  end

  defp rate_limited(conn, seconds_left) do
    conn
    |> put_status(429)
    |> json(%{
      state: "rate_limited",
      retry_after: seconds_left,
      message: "Refresh available again in #{seconds_left}s."
    })
  end

  defp do_refresh(conn, user_id, scope, slug, organization) do
    result = Models.RepositoryIntegrator.refresh_repositories(user_id, slug, organization)
    audit_refresh(conn, slug, organization, result)

    org_id = conn.assigns.organization_id
    resource = cooldown_resource(scope, organization)

    case result do
      {:ok, %{state: state, message: message}}
      when state in [:STARTED, :ALREADY_RUNNING, :DONE] ->
        json(conn, %{state: state |> Atom.to_string() |> String.downcase(), message: message})

      {:ok, %{message: message}} ->
        # A full/org business failure (e.g. no access) still ran the synchronous
        # org-push scan, so floor a short cooldown instead of fully releasing —
        # throttling a caller looping the same org against that scan. A targeted
        # failure likewise KEEPS its (full) cooldown so denied slugs cannot be
        # looped to spam the synchronous push check.
        if scope == :full,
          do: floor_refresh_cooldown(:full, org_id, user_id, resource)

        conn
        |> put_status(422)
        |> json(%{state: "failed", message: message})

      {:error, _} ->
        # Don't burn the user's cooldown on a transient RPC failure (either scope).
        release_refresh_cooldown(scope, org_id, user_id, resource)

        conn
        |> put_status(503)
        |> json(%{state: "failed", message: "Could not refresh repositories. Please retry."})
    end
  end

  # Audit every refresh that reaches the provider RPC, recording who triggered
  # it, the scope (full vs a single repository), and the resulting state — so a
  # refresh of another organization's repository leaves a trail.
  defp audit_refresh(conn, slug, organization, result) do
    {scope, resource_name} =
      cond do
        slug != "" -> {"targeted", slug}
        organization != "" -> {"organization", organization}
        true -> {"full", "all repositories"}
      end

    conn
    |> Audit.new(:Project, :Modified)
    |> Audit.add(
      description: "Refreshed the #{scope} GitHub App repository list",
      resource_name: resource_name
    )
    |> Audit.metadata(
      refresh_scope: scope,
      repository_slug: slug,
      organization: organization,
      result: refresh_result_state(result)
    )
    |> Audit.log()
  end

  defp refresh_result_state({:ok, %{state: state}}),
    do: state |> Atom.to_string() |> String.downcase()

  defp refresh_result_state(_), do: "error"

  # Scoped per (full vs targeted) so the two refresh kinds throttle independently,
  # and per resource (the normalized GitHub org for :full; "" for :targeted) so
  # refreshing one org doesn't lock out another.
  defp refresh_cooldown_key(scope, org_id, user_id, resource),
    do: "repository_refresh_cooldown/#{scope}/#{org_id}/#{user_id}/#{resource}"

  # GitHub logins are case-insensitive, so normalize to a single bucket. Targeted
  # stays per-user (no slug) on purpose — see start_targeted_refresh/4.
  defp cooldown_resource(:full, organization), do: String.downcase(organization)
  defp cooldown_resource(:targeted, _organization), do: ""

  # Soft cost-guard, not a lock. Claimed before the RPC, released if the refresh
  # did no work (see do_refresh/5). Two known limits, both bounded by the sync
  # worker's own unique lock (the real dedup), so the worst case is a few extra
  # GitHub calls: the get-then-set is non-atomic (Cacheman has no SET NX), and it
  # fails open if Redis is down (Cacheman maps errors to a cache miss). A proper
  # fix needs an atomic Redis SET NX claim.
  defp claim_refresh_cooldown(scope, org_id, user_id, resource) do
    key = refresh_cooldown_key(scope, org_id, user_id, resource)

    case Front.Cache.get(key) do
      {:ok, expires_at} ->
        {:cooldown, max(String.to_integer(expires_at) - System.system_time(:second), 1)}

      {:not_cached, _} ->
        write_refresh_cooldown(key, cooldown_seconds(scope))
        :ok
    end
  end

  # Reduce a held cooldown to a short floor (used on org business failure): the
  # scan already ran, so keep some throttle even though the full window is gone.
  defp floor_refresh_cooldown(scope, org_id, user_id, resource) do
    refresh_cooldown_key(scope, org_id, user_id, resource)
    |> write_refresh_cooldown(@full_refresh_failure_cooldown_seconds)
  end

  # The value is the absolute expiry, so a variable floor reports the right
  # retry_after; the TTL evicts the key when the window ends.
  defp write_refresh_cooldown(key, seconds) do
    Front.Cache.set(
      key,
      Integer.to_string(System.system_time(:second) + seconds),
      :timer.seconds(seconds)
    )
  end

  defp cooldown_seconds(:targeted), do: @targeted_refresh_cooldown_seconds
  defp cooldown_seconds(:full), do: @full_refresh_cooldown_seconds

  defp release_refresh_cooldown(scope, org_id, user_id, resource) do
    Front.Cache.unset(refresh_cooldown_key(scope, org_id, user_id, resource))
  end

  def project_repository_status(conn, params) do
    organization_id = conn.assigns.organization_id
    project = Models.Project.find(params["name_or_id"], organization_id)

    fetch_deploy_key = fetch_deploy_key(project)
    fetch_webhook = fetch_webhook(project)

    {:ok, {key, key_message}} = Async.await(fetch_deploy_key)
    {:ok, {hook, hook_message}} = Async.await(fetch_webhook)

    conn
    |> json(%{
      project_name: project.name,
      deploy_key: key,
      deploy_key_message: key_message,
      deploy_key_regenerate_url:
        project_settings_path(conn, :regenerate_deploy_key, project.name),
      hook: hook,
      hook_message: hook_message,
      hook_regenerate_url: project_settings_path(conn, :regenerate_webhook, project.name),
      connected: project.repo_connected,
      reset_webhook_secret_url:
        project_onboarding_path(conn, :regenerate_webhook_secret, project.name),
      agent_name: get_agent_name(project),
      agent_config_url: organization_pfc_path(conn, :show)
    })
  end

  defp fetch_deploy_key(project) do
    Async.run(fn ->
      case Front.Models.Project.check_deploy_key(project.id) do
        {:ok, key} -> {key, ""}
        {:error, message} -> {nil, message}
      end
    end)
  end

  defp fetch_webhook(project) do
    Async.run(fn ->
      case Front.Models.Project.check_webhook(project.id) do
        {:ok, hook} -> {hook, ""}
        {:error, message} -> {nil, message}
      end
    end)
  end

  def onboarding_index(conn, params) do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id
    project = conn.assigns.project

    fetch_user = Async.run(fn -> Models.User.find(user_id) end)
    maybe_cloud_agents = Async.run(fn -> FeatureProvider.list_machines(param: org_id) end)
    maybe_self_hosted_agents = Async.run(fn -> Front.SelfHostedAgents.AgentType.list(org_id) end)

    fetch_has_pipeline =
      Async.run(fn -> Models.Project.file_exists?(project.id, project.initial_pipeline_file) end)

    with {:ok, user} <- Async.await(fetch_user),
         {:ok, {:ok, cloud_agents}} <- Async.await(maybe_cloud_agents),
         {:ok, {:ok, self_hosted_agents}} <- Async.await(maybe_self_hosted_agents),
         {:ok, has_pipeline_file?} <- Async.await(fetch_has_pipeline) do
      conn
      |> render("bootstrap.html",
        js: "index_project_bootstrap",
        org_id: org_id,
        user: user,
        stage: params["stage"],
        name_or_id: params["name_or_id"],
        cloud_agents: cloud_agents,
        self_hosted_agents: self_hosted_agents,
        has_pipeline_file?: has_pipeline_file?
      )
    end
  end

  def update_project_initial_pipeline_file(conn, params) do
    project = conn.assigns.project
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id
    file_path = params["initial_pipeline_file"]
    changeset = Front.Models.Project.initial_pipeline_file_changeset(project, file_path)

    with {:ok, project_data} <- Ecto.Changeset.apply_action(changeset, :update),
         {:ok, _response} <- Front.Models.Project.update(project_data, user_id, org_id) do
      conn |> json(%{message: "Pipeline file updated"})
    else
      _e ->
        conn |> json(%{error: "Failed to update pipeline file"})
    end
  end

  @doc """
  Async action called from the "initializing" screen.

  The returned data indicates if the project is in "ready" state, or if not,
  what is yet missing to be ready.

  Responds with a JSON structure.
  """
  def is_ready(conn, _params) do
    alias Front.Onboarding.ReadinessCheck

    project = conn.assigns.project

    next_screen_url =
      if FeatureProvider.feature_enabled?(:new_project_onboarding,
           param: conn.assigns.organization_id
         ) do
        project_onboarding_path(conn, :onboarding_index, project.name, [""])
      else
        if Front.saas?() do
          project_onboarding_path(conn, :invite_collaborators, project.name)
        else
          if Models.Project.file_exists?(project.id, project.initial_pipeline_file) do
            project_onboarding_path(conn, :existing_configuration, project.name)
          else
            project_onboarding_path(conn, :template, project.name)
          end
        end
      end

    # move to :READY state automatically from onboarding
    if not FeatureProvider.feature_enabled?(:new_project_onboarding,
         param: conn.assigns.organization_id
       ) do
      if ReadinessCheck.should_make_ready?(project) do
        Front.Models.Project.finish_onboarding(project.id)
      end
    end

    response = %{
      ready: ReadinessCheck.ready(project),
      next_screen_url: next_screen_url,
      deps: %{
        connected_to_repository: ReadinessCheck.repository_ready(project),
        connected_to_artifacts: ReadinessCheck.artifacts_ready(project),
        connected_to_cache: ReadinessCheck.cache_ready(project),
        repo_analyzed: ReadinessCheck.analysis_ready(project),
        permissions_setup: ReadinessCheck.permissions_ready(project),
        is_connected: ReadinessCheck.is_connected(project)
      },
      waiting_message: ReadinessCheck.waiting_message(project),
      error_message: ReadinessCheck.error_message(project)
    }

    conn |> json(response)
  end

  def skip_onboarding(conn, _params) do
    Models.Project.finish_onboarding(conn.assigns.project.id)
    |> case do
      {:ok, _} ->
        conn |> json(%{redirect_to: project_path(conn, :show, conn.assigns.project.name)})

      {:error, _} ->
        conn |> json(%{error: "Failed to skip onboarding"})
    end
  end

  # this is just a trick to get rid of sobelow Config.CSRFRoute
  def x_workflow_builder(conn, params) do
    workflow_builder(conn, params)
  end

  # sobelow_skip ["Traversal.FileModule"]
  def workflow_builder(conn, params) do
    alias Front.Models.{AgentType, Deployments, Organization, Secret, User}

    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id
    project = conn.assigns.project

    fetch_user = Async.run(fn -> User.find(user_id) end)
    fetch_org = Async.run(fn -> Organization.find(org_id) end)

    fetch_secrets =
      Async.run(fn -> Secret.list(user_id, org_id, project.id, :ORGANIZATION, true) end)

    fetch_agent_types = Async.run(fn -> AgentType.list(org_id) end)

    fetch_self_hosted_agent_types =
      Async.run(fn -> Front.SelfHostedAgents.AgentType.list(org_id) end,
        metric: "workflow.edit.fetch_self_hosted_agent_types"
      )

    fetch_deployment_targets = Async.run(fn -> Deployments.fetch_targets(project.id) end)

    {:ok, organization} = Async.await(fetch_org)
    {:ok, user} = Async.await(fetch_user)
    {:ok, secrets} = Async.await(fetch_secrets)
    {:ok, {:ok, hosted_agent_types}} = Async.await(fetch_agent_types)
    {:ok, {:ok, self_hosted_agent_types}} = Async.await(fetch_self_hosted_agent_types)
    {:ok, {:ok, deployment_targets}} = Async.await(fetch_deployment_targets)

    self_hosted =
      self_hosted_agent_types
      |> Enum.map(fn a -> %{type: a.name, platform: "SELF_HOSTED", specs: "", os_image: ""} end)

    combined = hosted_agent_types.agent_types ++ self_hosted

    agent_types = %{
      hosted_agent_types
      | agent_types: combined
    }

    template_content =
      if FeatureProvider.feature_enabled?(:new_project_onboarding, param: org_id) do
        get_pipeline_from_template(params, org_id)
      else
        if valid_template_path?(params["templatePath"]) do
          params["templatePath"]
        else
          "templates/simple.yml"
        end

        Application.get_env(:front, :workflow_templates_path)
        |> Path.join("#{params["templatePath"]}")
        |> File.read!()
      end

    path =
      if FeatureProvider.feature_enabled?(:new_project_onboarding, param: org_id) do
        Map.get(params, "yaml_path", Models.Project.initial_semaphore_yaml_path())
      else
        Models.Project.initial_semaphore_yaml_path()
      end

    conn
    |> render(
      "setup.html",
      project_setup_phase: "Set up workflow",
      js: :workflow_editor,
      project: project,
      organization: organization,
      user: user,
      title: "#{project.name}・#{organization.name}",
      secrets: secrets,
      commiter_avatar: user.avatar_url,
      agent_types: agent_types,
      template_title: params["templateTitle"],
      yamls: %{
        path => template_content
      },
      deployment_targets: Enum.map(deployment_targets, & &1.name),
      hide_promotions: Application.get_env(:front, :hide_promotions, false)
    )
  end

  # sobelow_skip ["Traversal.FileModule"]
  def commit_starter_template(conn, params) do
    if FeatureProvider.feature_enabled?(:new_project_onboarding,
         param: conn.assigns.organization_id
       ) do
      commit_starter_template_new(conn, params)
    else
      commit_starter_template_old(conn, params)
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp commit_starter_template_new(conn, params) do
    conn.assigns.project.integration_type
    |> case do
      :GIT ->
        org_id = conn.assigns.organization_id

        filename = Map.get(params, "commit_path", Models.Project.initial_semaphore_yaml_path())
        content = get_pipeline_from_template(params, org_id)

        conn
        |> FrontWeb.ProjectController.commit_config(
          params
          |> Map.merge(%{
            "initial_branch" => conn.assigns.project.repo_default_branch,
            "branch" => "setup-semaphore",
            "commit_message" => "Use #{params["template_title"]} starter workflow",
            "added_files" => [%{filename: filename, content: content}]
          })
        )

      _ ->
        alias Front.Models.Repohub
        alias InternalApi.Repository.CommitRequest.Change

        repository_id = conn.assigns.project.repo_id
        user_id = conn.assigns.user_id
        org_id = conn.assigns.organization_id

        branch = "setup-semaphore"
        message = "Use #{params["template_title"]} starter workflow"

        content = get_pipeline_from_template(params, org_id)
        path = Map.get(params, "commit_path", Models.Project.initial_semaphore_yaml_path())

        change =
          Change.new(
            action: Change.Action.value(:ADD_FILE),
            file: InternalApi.Repository.File.new(path: path, content: content)
          )

        request =
          InternalApi.Repository.CommitRequest.new(
            repository_id: repository_id,
            user_id: user_id,
            branch_name: branch,
            commit_message: message,
            changes: [change]
          )

        case Repohub.commit(request) do
          {:ok, res} ->
            # signal that project onboarding is complete
            Front.Async.run(fn ->
              Models.Project.finish_onboarding(conn.assigns.project.id)
            end)

            conn
            |> put_status(201)
            |> json(%{
              message: "Config committed. Waiting for Workflow to start.",
              branch: branch,
              commit_sha: res.revision.commit_sha
            })

          {:error, error} ->
            conn
            |> put_status(422)
            |> json(%{error: error.message})
        end
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp commit_starter_template_old(conn, params) do
    alias Front.Models.Repohub
    alias InternalApi.Repository.CommitRequest.Change

    repository_id = conn.assigns.project.repo_id
    user_id = conn.assigns.user_id

    branch = "setup-semaphore"
    message = "Use #{params["templateTitle"]} starter workflow"

    params_template_path =
      Application.get_env(:front, :workflow_templates_path)
      |> Path.join("#{params["templatePath"]}")

    template_path =
      if valid_template_path?(params_template_path) do
        params_template_path
      else
        Application.get_env(:front, :workflow_templates_path)
        |> Path.join("templates/simple.yml")
      end

    content = File.read!(template_path)
    path = Models.Project.initial_semaphore_yaml_path()

    change =
      Change.new(
        action: Change.Action.value(:ADD_FILE),
        file: InternalApi.Repository.File.new(path: path, content: content)
      )

    request =
      InternalApi.Repository.CommitRequest.new(
        repository_id: repository_id,
        user_id: user_id,
        branch_name: branch,
        commit_message: message,
        changes: [change]
      )

    case Repohub.commit(request) do
      {:ok, res} ->
        conn
        |> put_status(201)
        |> json(%{
          message: "Config committed. Waiting for Workflow to start.",
          branch: branch,
          commit_sha: res.revision.commit_sha
        })

      {:error, error} ->
        conn
        |> put_status(422)
        |> json(%{error: error.message})
    end
  end

  #
  # Helper functions
  #

  defp get_pipeline_from_template(params, organization_id) do
    template_content =
      case Front.WorkflowTemplate.fetch_from_path(params["template_path"]) do
        {:ok, content} -> content
        {:error, _reason} -> Front.WorkflowTemplate.simple(organization_id)
      end

    Front.WorkflowTemplate.process_template(template_content, params)
  end

  defp atomize_integration_type(integration_type) do
    InternalApi.RepositoryIntegrator.IntegrationType.key(integration_type)
  end

  defp maybe_filter_bitbucket(integration_types, org_id) do
    if show_bitbucket?(org_id) do
      integration_types
    else
      Enum.reject(integration_types, fn integration_type -> integration_type == :BITBUCKET end)
    end
  end

  #
  defp valid_template_path?(path) do
    !String.contains?(path, "..")
  end

  def filter_members(collaborators, members) do
    collaborators |> Enum.filter(fn collaborator -> member?(collaborator, members) end)
  end

  defp member?(collaborator, members) do
    members |> Enum.any?(fn member -> member.github_username == collaborator.login end)
  end

  defp integration_choose_repository_path(conn, integration_type)

  defp integration_choose_repository_path(conn, nil),
    do: github_legacy_choose_repository_path(conn, :choose_repository)

  defp integration_choose_repository_path(conn, ""),
    do: github_legacy_choose_repository_path(conn, :choose_repository)

  defp integration_choose_repository_path(conn, "github_app"),
    do: github_choose_repository_path(conn, :choose_repository)

  defp integration_choose_repository_path(conn, "github_oauth_token"),
    do: github_legacy_choose_repository_path(conn, :choose_repository)

  defp integration_choose_repository_path(conn, "bitbucket"),
    do: bitbucket_choose_repository_path(conn, :choose_repository)

  defp org_choose_repository_path(conn) do
    case Models.Organization.repository_integrators(conn.assigns.organization_id) do
      {_, %{primary: 2}} ->
        integration_choose_repository_path(conn, "bitbucket")

      {_, %{primary: 1}} ->
        integration_choose_repository_path(conn, "github_app")

      {_, %{primary: 0}} ->
        integration_choose_repository_path(conn, "github_oauth_token")
    end
  end

  defp check_integration_type(conn, integrations, :github_oauth_token),
    do:
      check_integration_type_result(
        conn,
        Enum.member?(integrations.enabled, 0),
        integrations.primary
      )

  defp check_integration_type(conn, integrations, :github_app),
    do:
      check_integration_type_result(
        conn,
        Enum.member?(integrations.enabled, 1),
        integrations.primary
      )

  defp check_integration_type(conn, integrations, :bitbucket),
    do:
      check_integration_type_result(
        conn,
        Enum.member?(integrations.enabled, 2),
        integrations.primary
      )

  defp check_integration_type(conn, integrations, _),
    do: check_integration_type_result(conn, false, integrations.primary)

  defp check_integration_type_result(_, true, _), do: :ok

  defp check_integration_type_result(conn, false, 0),
    do: integration_choose_repository_path(conn, "github_oauth_token")

  defp check_integration_type_result(conn, false, 1),
    do: integration_choose_repository_path(conn, "github_app")

  defp check_integration_type_result(conn, false, 2),
    do: integration_choose_repository_path(conn, "bitbucket")

  defp check_integration_type_result(conn, false, _),
    do: integration_choose_repository_path(conn, nil)

  defp show_bitbucket?(org_id), do: FeatureProvider.feature_enabled?(:bitbucket, param: org_id)
end
