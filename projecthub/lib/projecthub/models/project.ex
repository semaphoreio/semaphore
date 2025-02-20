# credo:disable-for-this-file
defmodule Projecthub.Models.Project do
  use Ecto.Schema

  require Logger
  import Ecto.Changeset
  import Ecto.Query
  import Toolkit
  alias __MODULE__
  alias Projecthub.Models.Repository
  alias Projecthub.Models.DeployKey
  alias Projecthub.Models.PeriodicTask
  alias Projecthub.Repo
  alias Projecthub.Events
  alias Projecthub.Schedulers
  alias Projecthub.Models.Project.StateMachine

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "projects" do
    has_one(:deploy_key, DeployKey, on_delete: :delete_all)
    has_one(:sql_repository, Repository.SQL)

    field(:name, :string)
    field(:description, :string, default: "")
    field(:created_at, :utc_datetime)
    field(:updated_at, :utc_datetime)
    field(:creator_id, :binary_id)
    field(:organization_id, :binary_id)

    field(:cache_id, :binary_id)
    field(:artifact_store_id, :binary_id)
    field(:docker_registry_id, :binary_id)

    field(:build_tag, :boolean, default: true)
    field(:build_branch, :boolean, default: true)
    field(:build_pr, :boolean, default: false)
    field(:build_forked_pr, :boolean, default: false)

    field(:allowed_secrets, :string, default: "")
    field(:allowed_contributors, :string, default: "")

    field(:public, :boolean, default: false)
    field(:request_id, :binary_id)

    field(:state, :string)
    field(:state_reason, :string)

    field(:analysis, :map)

    field(:custom_permissions, :boolean, default: false)
    field(:permissions_setup, :boolean, default: false)

    field(:debug_empty, :boolean, default: false)
    field(:debug_default_branch, :boolean, default: false)
    field(:debug_non_default_branch, :boolean, default: false)
    field(:debug_pr, :boolean, default: false)
    field(:debug_forked_pr, :boolean, default: false)
    field(:debug_tag, :boolean, default: false)

    field(:attach_default_branch, :boolean, default: false)
    field(:attach_non_default_branch, :boolean, default: false)
    field(:attach_pr, :boolean, default: false)
    field(:attach_forked_pr, :boolean, default: false)
    field(:attach_tag, :boolean, default: false)

    field(:repository, :map, virtual: true)
    # embeds_one(:repository, Repository)
  end

  def create(request_id, user, org, project_spec, repo_details, integration_type, skip_onboarding \\ false) do
    Toolkit.log("Creating a new project for #{org.id} from #{repo_details.url}")

    initial_state =
      cond do
        FeatureProvider.feature_enabled?(:new_project_onboarding, org.id) ->
          if skip_onboarding, do: StateMachine.skip_onboarding(), else: StateMachine.initial()

        true ->
          StateMachine.skip_onboarding()
      end

    project_spec
    |> Map.merge(%{
      organization_id: org.id,
      creator_id: user.id,
      # repo_details.description,
      description: "",
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      state: initial_state,
      request_id: if(request_id == "", do: nil, else: request_id)
    })
    |> changeset()
    |> Repo.insert()
    |> unwrap_error(fn failed_changeset ->
      failed_changeset.errors
      |> Enum.any?(&(elem(&1, 0) == :request_id))
      |> case do
        true ->
          Logger.info("The request #{request_id} was already processed, returning project")
          Repo.get_by(__MODULE__, request_id: request_id) |> wrap()

        false ->
          Logger.error("Failed to create a project: #{inspect(failed_changeset.errors)}")
          error("Project creation failed")
      end
    end)
    |> unwrap(fn project ->
      Repository.create(%{
        project_id: project.id,
        user_id: project.creator_id,
        pipeline_file: repo_details.pipeline_file,
        repository_url: repo_details.url,
        only_public: org.open_source,
        integration_type: repo_details.integration_type,
        commit_status: repo_details.commit_status,
        whitelist: repo_details.whitelist,
        request_id: request_id
      })
      |> unwrap_error(fn error ->
        Repo.delete(project)
        {:error, error}
      end)
      |> unwrap(fn repository ->
        %{project | repository: repository}
      end)
    end)
    |> unwrap(fn project ->
      initialize_project_async(project.id)
      wrap(project)
    end)
  end

  def update_record(project, params) do
    changeset =
      changeset(
        project,
        Map.merge(
          params,
          %{updated_at: DateTime.utc_now()}
        )
      )

    Repo.update(changeset)
  end

  def update(project, project_params, repo_params, schedulers, tasks, requester_id, omit_schedulers_and_tasks \\ false) do
    cond do
      omit_schedulers_and_tasks ->
        update_without_schedulers_and_tasks(project, project_params, repo_params)

      Enum.empty?(tasks) ->
        update_with_schedulers(project, project_params, repo_params, schedulers, requester_id)

      true ->
        update_with_tasks(project, project_params, repo_params, tasks, requester_id)
    end
  end

  def update_with_schedulers(project, project_params, repo_params, schedulers, requester_id) do
    with {:ok, project} <- update_record(project, project_params),
         {:ok, _} <- Schedulers.update(project, schedulers, requester_id),
         {:ok, _} <- Repository.update(project.repository, repo_params),
         {:ok, _} <- Events.ProjectUpdated.publish(project) do
      # Re-load the record. Repository update might have changed the values.
      find(project.id)
    else
      {:error, changeset = %Ecto.Changeset{}} ->
        {:error, [parse_error_msg(changeset.errors)]}

      e ->
        e
    end
  end

  def update_with_tasks(project, project_params, repo_params, tasks, requester_id) do
    with {:ok, project} <- update_record(project, project_params),
         {:ok, _} <- PeriodicTask.update_all(project, tasks, requester_id),
         {:ok, _} <- Repository.update(project.repository, repo_params),
         {:ok, _} <- Events.ProjectUpdated.publish(project) do
      # Re-load the record. Repository update might have changed the values.
      find(project.id)
    else
      {:error, changeset = %Ecto.Changeset{}} ->
        {:error, [parse_error_msg(changeset.errors)]}

      e ->
        e
    end
  end

  def update_without_schedulers_and_tasks(project, project_params, repo_params) do
    with {:ok, project} <- update_record(project, project_params),
         {:ok, _} <- Repository.update(project.repository, repo_params),
         {:ok, _} <- Events.ProjectUpdated.publish(project) do
      # Re-load the record. Repository update might have changed the values.
      find(project.id)
    else
      {:error, changeset = %Ecto.Changeset{}} ->
        {:error, [parse_error_msg(changeset.errors)]}

      e ->
        e
    end
  end

  def changeset(project \\ %Project{}, params) do
    project
    |> cast(params, [
      :name,
      :description,
      :created_at,
      :updated_at,
      :creator_id,
      :organization_id,
      :cache_id,
      :artifact_store_id,
      :docker_registry_id,
      :build_tag,
      :build_branch,
      :build_pr,
      :build_forked_pr,
      :allowed_secrets,
      :allowed_contributors,
      :public,
      :request_id,
      :state,
      :state_reason,
      :analysis,
      :custom_permissions,
      :permissions_setup,
      :debug_empty,
      :debug_default_branch,
      :debug_non_default_branch,
      :debug_pr,
      :debug_forked_pr,
      :debug_tag,
      :attach_default_branch,
      :attach_non_default_branch,
      :attach_pr,
      :attach_forked_pr,
      :attach_tag
    ])
    |> validate_required([:name, :organization_id, :creator_id])
    |> validate_format(:name, ~r/\A[\w\-\.]+\z/,
      message: "Project name can have only alphanumeric characters, underscore and dash"
    )
    |> unique_constraint(:request_id, name: :index_projects_on_request_id)
  end

  def find(id) do
    if id_is_uuid?(id) do
      case Repo.get_by(Project, id: id) do
        nil -> {:error, :not_found}
        project -> {:ok, project}
      end
    else
      {:error, :not_found}
    end
    |> unwrap(&preload_repository/1)
  end

  def find_in_org(org_id, id) do
    if id_is_uuid?(id) and id_is_uuid?(org_id) do
      case Repo.get_by(__MODULE__, id: id, organization_id: org_id) do
        nil -> {:error, :not_found}
        project -> {:ok, project}
      end
    else
      {:error, :not_found}
    end
    |> unwrap(&preload_repository/1)
  end

  def id_is_uuid?(id) do
    case Ecto.UUID.dump(id) do
      {:ok, _} -> true
      _ -> false
    end
  end

  def find_by_name(name, org_id) do
    case Repo.get_by(Project, name: name, organization_id: org_id) do
      nil -> {:error, :not_found}
      project -> {:ok, project}
    end
    |> unwrap(&preload_repository/1)
  end

  def destroy(project, user) do
    {:ok, repository} = Repository.find_for_project(project.id)
    {:ok, _} = Repository.destroy(repository)

    {:ok, _} = Repo.delete(project)
    {:ok, _} = Schedulers.delete_all(project, user.id)
    {:ok, _} = Events.ProjectDeleted.publish(project)

    {:ok, _} = Task.start(Projecthub.Artifact, :destroy, [project.artifact_store_id, project.id])
    {:ok, _} = Task.start(Projecthub.Cache, :destroy, [project.cache_id, project.id])

    {:ok, nil}
  end

  def find_many(org_id, ids) do
    Project
    |> where([p], p.organization_id == ^org_id)
    |> where([p], p.id in ^ids)
    |> Repo.all()
    |> preload_repositories()
  end

  def count_in_org(org_id) do
    Project
    |> where([p], p.organization_id == ^org_id)
    |> Repo.aggregate(:count, :id)
  end

  def list_per_page(org_id, page, page_size, options \\ []) do
    defaults = [
      owner_id: nil,
      repo_url: nil
    ]

    filters = [
      org_id: org_id,
      states: [StateMachine.ready(), StateMachine.onboarding()]
    ]

    options =
      defaults
      |> Keyword.merge(options)
      |> Keyword.merge(filters)

    Project
    |> filter_by(options)
    |> Repo.paginate(page: page, page_size: page_size)
    |> case do
      %{entries: entries} = paged_result ->
        %{paged_result | entries: preload_repositories(entries)}
    end
  end

  def list_per_page_with_cursor(org_id, cursor, direction, page_size, options \\ []) do
    defaults = [
      owner_id: nil,
      repo_url: nil,
      created_after: nil
    ]

    filters = [
      org_id: org_id,
      states: [StateMachine.ready(), StateMachine.onboarding()]
    ]

    options =
      defaults
      |> Keyword.merge(options)
      |> Keyword.merge(filters)

    cursor = if cursor == "", do: nil, else: cursor

    cursor_after = if direction == :NEXT, do: cursor, else: nil
    cursor_before = if direction == :PREVIOUS, do: cursor, else: nil

    Project
    |> filter_by(options)
    |> order_by([p], asc: p.organization_id, asc: p.name)
    |> Repo.cursor_paginate(
      cursor_fields: [:organization_id, :name],
      limit: page_size,
      after: cursor_after,
      before: cursor_before
    )
    |> case do
      %{entries: entries} = paged_result ->
        %{paged_result | entries: preload_repositories(entries)}
    end
  end

  defp filter_by(query, options) do
    options
    |> Enum.reduce(query, fn
      {:created_after, value}, query ->
        filter_by_created_after(query, value)

      {:owner_id, value}, query ->
        filter_by_owner(query, value)

      {:repo_url, value}, query ->
        filter_by_repo_url(query, value)

      {:org_id, value}, query ->
        filter_by_org_id(query, value)

      {:state, value}, query ->
        query
        |> where([project], project.state == ^value)

      {:states, values}, query ->
        query
        |> where([project], project.state in ^values)

      _, query ->
        query
    end)
  end

  def preload_repository(%{repository: %Repository{}} = project), do: wrap(project)

  def preload_repository(project) do
    Repository.find_for_project(project.id)
    |> case do
      {:ok, repository} ->
        %{project | repository: repository}

      _ ->
        project
    end
    |> wrap
  end

  def preload_repositories(projects) do
    repositories =
      projects
      |> Enum.map(fn
        %{repository: %Repository{}} -> nil
        project -> project.id
      end)
      |> Enum.filter(& &1)
      |> Repository.find_for_project_ids()

    projects
    |> Enum.map(fn project ->
      Enum.find(repositories, fn repository ->
        repository.project_id == project.id
      end)
      |> case do
        nil -> project
        repository -> %{project | repository: repository}
      end
    end)
  end

  defp filter_by_created_after(query, nil), do: query

  defp filter_by_created_after(query, created_after),
    do: query |> where([project], project.created_at > ^created_after)

  defp filter_by_org_id(query, org_id) when is_binary(org_id) and org_id != "",
    do: query |> where([project], project.organization_id == ^org_id)

  defp filter_by_org_id(query, _), do: query

  defp filter_by_owner(query, owner_id) do
    if id_is_uuid?(owner_id) do
      query
      |> where([project], project.creator_id == ^owner_id)
    else
      query
    end
  end

  defp filter_by_repo_url(query, repo_url) do
    if is_binary(repo_url) and repo_url != "" do
      query
      |> join(:left, [project], repository in assoc(project, :sql_repository), as: :repository)
      |> where([project, repository: repository], repository.url == ^repo_url)
    else
      query
    end
  end

  defp parse_error_msg([{:name, {message, _}} | _]), do: message

  #
  # Tries to initialize project async by manually triggering the worker
  # process.

  # The result of the processing attempt can't interfere with project
  # creation. We use spawn instead of spawn_link.
  #
  defp initialize_project_async(project_id) do
    spawn(fn ->
      :timer.sleep(1000)
      Projecthub.Workers.ProjectInit.lock_and_process(project_id)
    end)
  end
end
