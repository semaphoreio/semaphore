defmodule FrontWeb.ProjectForkController do
  use FrontWeb, :controller
  require Logger

  alias Front.Async
  alias Front.Models
  alias Front.Onboarding

  plug(
    FrontWeb.Plugs.OrganizationAuthorization
    when action in [
           :fork,
           :initializing,
           :is_ready
         ]
  )

  plug(
    FrontWeb.Plugs.Header
    when action in [
           :initializing
         ]
  )

  def fork(conn, params) do
    Watchman.benchmark("project.fork.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id
      name = params["repository_name"]
      provider = params["provider"]

      fetch_user = Async.run(fn -> Models.User.find(user_id) end)
      fetch_organization = Async.run(fn -> Models.Organization.find(org_id) end)

      repository = Models.Forkable.find(name)
      {:ok, user} = Async.await(fetch_user)

      if Models.Forkable.supported_by_user?(user, provider) do
        conn
        |> init_fork(repository, provider)
      else
        {:ok, organization} = Async.await(fetch_organization)

        domain = Application.get_env(:front, :domain)

        path =
          "https://#{organization.username}.#{domain}#{project_fork_path(conn, :after_auth, provider, repository.name)}"

        url = "https://id.#{domain}/#{provider}?access_level=public&redirect_path=#{path}"

        redirect(conn, external: url)
      end
    end)
  end

  defp init_fork(conn, repository, provider) do
    uuid = Ecto.UUID.generate()

    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id

    fork = %{
      name: repository.project_name,
      url: Models.Forkable.repository_url(repository, provider),
      integration_type: Models.Forkable.map_repository_provider(provider)
    }

    Async.run(fn -> Onboarding.Forking.fork(org_id, user_id, fork, uuid) end)

    conn
    |> redirect(to: project_fork_path(conn, :initializing, repository.name, uuid))
  end

  def after_auth(conn, params) do
    Watchman.benchmark("project.after_auth.duration", fn ->
      user_id = conn.assigns.user_id
      name = params["repository_name"]
      provider = params["provider"]
      org_id = conn.assigns.organization_id

      fetch_user = Async.run(fn -> Models.User.find(user_id) end)

      repository = Models.Forkable.find(name)
      {:ok, user} = Async.await(fetch_user)

      if Models.Forkable.supported_by_user?(user, provider) do
        conn
        |> init_fork(repository, provider)
      else
        redirect_path =
          if FeatureProvider.feature_enabled?(:new_project_onboarding, org_id) do
            project_onboarding_path(conn, :index)
          else
            project_onboarding_path(conn, :new)
          end

        conn
        |> put_flash(:alert, "Failed to connect with Repository.")
        |> redirect(to: redirect_path)
      end
    end)
  end

  def initializing(conn, params) do
    name = params["repository_name"]
    uuid = params["fork_uuid"]

    repository = Models.Forkable.find(name)

    conn
    |> put_view(FrontWeb.ProjectOnboardingView)
    |> render("initializing.html",
      js: "projectOnboardingInitializing",
      check_url: project_fork_path(conn, :is_ready, uuid),
      title: "Initializing・#{repository.name}"
    )
  end

  def is_ready(conn, params) do
    uuid = params["fork_uuid"]

    case start_workflow(conn, uuid) do
      {:error, message} ->
        conn
        |> json(error_response(message, :error, nil))

      {:error, message, project} ->
        conn
        |> json(error_response(message, project, :error))

      {project, workflow, url} ->
        conn
        |> json(success_reponse(project, workflow, url))

      project ->
        conn
        |> json(success_reponse(project, nil, ""))
    end
  end

  defp start_workflow(conn, uuid) when is_binary(uuid) do
    case Onboarding.Forking.get_project(uuid) do
      {:ok, nil} ->
        nil

      {:ok, project} ->
        start_workflow(conn, project)

      {:error, message} ->
        {:error, message}
    end
  end

  defp start_workflow(conn, project) do
    case Onboarding.Forking.start_workflow(project) do
      {:ok, :not_ready} ->
        project

      {:error, message} ->
        {:error, message, project}

      {:ok, workflow} ->
        {project, workflow,
         workflow_path(conn, :show, workflow.workflow_id,
           pipeline_id: workflow.pipeline_id,
           fork: true
         )}
    end
  end

  defp success_reponse(project, workflow, url) do
    alias Front.Onboarding.ReadinessCheck

    %{
      ready: ReadinessCheck.ready(project, workflow),
      next_screen_url: url,
      deps: %{
        forking_repository: ReadinessCheck.forking_ready(project),
        connected_to_repository: ReadinessCheck.repository_ready(project),
        connected_to_artifacts: ReadinessCheck.artifacts_ready(project),
        connected_to_cache: ReadinessCheck.cache_ready(project),
        repo_analyzed: ReadinessCheck.analysis_ready(project),
        first_workflow: ReadinessCheck.workflow_ready(workflow)
      },
      waiting_message: ReadinessCheck.waiting_message(project, workflow),
      error_message: ""
    }
  end

  defp error_response(message, project, workflow) do
    alias Front.Onboarding.ReadinessCheck

    %{
      ready: false,
      next_screen_url: "",
      deps: %{
        forking_repository: ReadinessCheck.forking_ready(project),
        connected_to_repository: ReadinessCheck.repository_ready(project),
        connected_to_artifacts: ReadinessCheck.artifacts_ready(project),
        connected_to_cache: ReadinessCheck.cache_ready(project),
        repo_analyzed: ReadinessCheck.analysis_ready(project),
        first_workflow: ReadinessCheck.workflow_ready(workflow)
      },
      waiting_message: "",
      error_message: message
    }
  end
end
