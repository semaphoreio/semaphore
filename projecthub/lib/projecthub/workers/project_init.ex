defmodule Projecthub.Workers.ProjectInit do
  import Toolkit
  require Logger

  alias Projecthub.RepositoryHubClient
  alias Projecthub.RbacClient
  alias Projecthub.Models.Project.StateMachine
  alias Projecthub.Repo
  alias Projecthub.Events

  @doc """
  The ProjectInit is responsible for creating all the necessary dependencies
  for a project.

  A project has the following dependencies:

    - A Deploy Hook and a Deploy Key on GitHub
    - An Artifact storage
    - A Cache storage
    - A pre-heated Repository in our local storage (i.e., the repo is cloned)

  In each cycle of this worker, all the projects that are
  `project.state == "initializing"` are processed. When all the dependencies of
  a project are set up, the project transitions to the "onboarding" state.
  """

  @init_timeout_in_minutes 20
  @metric_name "workers.project_creator"

  import Ecto.Query

  def start_link(_) do
    {:ok, spawn_link(&loop/0)}
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def loop do
    Task.async(fn -> tick() end) |> Task.await(:infinity)

    :timer.sleep(1000)

    loop()
  end

  @doc """
  On every tick, we load all the project ids that are not yet ready.

  For every such project, we try to acquire a DB lock, and process it.
  """
  def tick do
    ids =
      Watchman.benchmark("#{@metric_name}.tick.duration", fn ->
        Projecthub.Models.Project
        |> where([p], p.state == ^StateMachine.initializing() or p.state == ^StateMachine.initializing_skip())
        |> select([p], p.id)
        |> Projecthub.Repo.all()
      end)

    if ids == [] do
      Logger.info("No project to initialize. Sleeping.")
    else
      Logger.info("Processing #{inspect(ids)}")

      ids |> Enum.each(fn id -> lock_and_process(id) end)
    end
  end

  @doc """
  The lock and process mechanism takes a project_id and tries to set up all the
  necessary dependencies for a project.

  This method can be used directly, for example, from the project API after the
  create RPC action. Or, it can be used from the above tick action.

  The direct invocation of the function is faster (it processes immediately), but
  is not fault tolerant. The invocation from the worker is slower (the tick can
  load multiple projects, each of which needs processing), but it is fault
  tolerant in the sense that it will retry project creation.
  """
  def lock_and_process(project_id) do
    Watchman.benchmark("#{@metric_name}.process.duration", fn ->
      Projecthub.Repo.transaction(fn ->
        project =
          Projecthub.Models.Project
          |> where([p], p.state == ^StateMachine.initializing() or p.state == ^StateMachine.initializing_skip())
          |> where([p], p.id == ^project_id)
          |> lock("FOR UPDATE SKIP LOCKED")
          |> Repo.one()

        if is_nil(project) do
          Watchman.increment("#{@metric_name}.process.lock_missed")
        else
          Watchman.increment("#{@metric_name}.process.lock_obtained")

          process(project)
        end
      end)
    end)
  end

  # @doc """
  # Private implementation of the project processing. Do not call this method
  # directly without obtaining a lock in the lock_and_process method.
  # """
  defp process(project) do
    Logger.info("Processing #{project.id}")

    if DateTime.to_unix(project.created_at) <
         DateTime.to_unix(DateTime.utc_now()) - @init_timeout_in_minutes * 60 do
      timeout_project_init(project)

      false
    else
      project = Repo.preload(project, :deploy_key)

      RepositoryHubClient.describe_many(%{project_ids: [project.id]})
      |> case do
        {:ok, %{repositories: [repository | _]}} ->
          deps = %{
            "connected_to_github" => handle_all_errors(fn -> connect_to_github(repository) end),
            "setup_permissions" => handle_all_errors(fn -> setup_permissions(project) end),
            "connect_to_cachehub" => handle_all_errors(fn -> connect_to_cachehub(project) end),
            "connect_to_artifacthub" => handle_all_errors(fn -> connect_to_artifacthub(project) end),
            "repo_analyzed" => handle_all_errors(fn -> analyze_repository(project, repository) end),
            "collaborators_pulled" => handle_all_errors(fn -> check_collaborators(repository) end)
          }

          process_result(project, deps)

        _ ->
          Logger.warn("Can't process project #{project.id} - repository not ready.")
          :ok
      end
    end
  end

  defp timeout_project_init(project) do
    Projecthub.Models.Project.update_record(project, %{
      :state => StateMachine.error(),
      :state_reason => "Project initialization timeout."
    })
  end

  # @doc """
  # The result of the dependency creation can be one of the following

  # 1. All the deps are ready (:ok). In this case, we set the state to :ready.

  # 2. There is an unrecovarable error (retries won't help) while creating a
  # dependency, for example github repository does not exists. State of
  # the dependency will be set to {:error, :unrecovarable, reason}

  # 3. There are errors while processing the deps. We should retry.
  # """
  defp process_result(project, deps) do
    cond do
      deps_ready?(deps) ->
        Logger.info("Progressing project #{project.id} state")

        {:ok, _} = StateMachine.transition(project, StateMachine.next(project))

        Events.ProjectCreated.publish(%{
          project_id: project.id,
          organization_id: project.organization_id
        })

        Logger.info("Project #{project.id} initialization done")

        true

      deps_unrecoverable?(deps) ->
        errors =
          deps
          |> Enum.filter(fn
            {_, v} ->
              v != :ok and
                elem(v, 1) == :unrecovarable
          end)
          |> Enum.map_join("; ", fn {_, v} -> elem(v, 2) end)

        Logger.info("Setting project #{project.id} state to error. Errors: #{errors}.")

        {:ok, project} = Projecthub.Models.Project.update_record(project, %{:state_reason => errors})

        {:ok, _} = StateMachine.transition(project, StateMachine.error())

        Logger.info("Project #{project.id} initialization failed.")

        false

      true ->
        Logger.error("Project #{project.id} initialization failed. State of deps: #{inspect(deps)}")

        false
    end
  end

  defp deps_ready?(deps) do
    deps |> Enum.all?(fn {_, v} -> v == :ok end)
  end

  defp deps_unrecoverable?(deps) do
    deps
    |> Enum.filter(fn {_, v} -> v != :ok end)
    |> Enum.any?(fn {_, v} -> elem(v, 1) == :unrecovarable end)
  end

  defp connect_to_cachehub(project) do
    if System.get_env("SKIP_CACHE") == "true" do
      :ok
    else
      do_connect_to_cachehub(project)
    end
  end

  defp do_connect_to_cachehub(project) do
    if project.cache_id == nil do
      Logger.info("Creating cache store for #{project.id}")

      :ok = Projecthub.Cache.create_for_project(project.id)
    else
      :ok
    end
  end

  defp connect_to_github(repository) do
    import Toolkit

    log("Setting up git connection for project #{repository.project_id}")

    with {:ok, _} <- setup_deploy_key(repository.id),
         {:ok, _} <- setup_webhook(repository.id) do
      :ok
    else
      {:error, error} ->
        {:error, :unrecovarable, error.message}
    end
  end

  defp setup_deploy_key(repository_id) do
    not_found = GRPC.Status.not_found()
    unimplemented = GRPC.Status.unimplemented()

    RepositoryHubClient.check_deploy_key(%{repository_id: repository_id})
    |> unwrap_error(fn
      %{status: ^unimplemented} ->
        {:ok, nil}

      %{status: ^not_found} ->
        RepositoryHubClient.regenerate_deploy_key(%{repository_id: repository_id})

      error ->
        error(error)
    end)
  end

  defp setup_webhook(repository_id) do
    not_found = GRPC.Status.not_found()
    unimplemented = GRPC.Status.unimplemented()

    RepositoryHubClient.check_webhook(%{repository_id: repository_id})
    |> unwrap_error(fn
      %{status: ^unimplemented} ->
        {:ok, nil}

      %{status: ^not_found} ->
        RepositoryHubClient.regenerate_webhook(%{repository_id: repository_id})

      error ->
        error(error)
    end)
  end

  defp setup_permissions(project) do
    Logger.info("Setting up permissions for project #{project.id}")

    case RbacClient.assign_role(project.creator_id, project.organization_id, project.id, "Admin") do
      :ok ->
        {:ok, _} = Projecthub.Models.Project.update_record(project, %{permissions_setup: true})
        Logger.info("Permissions created for project #{project.id}")

      _ ->
        error("Permission setup failed")
    end
  end

  defp connect_to_artifacthub(project) do
    if project.artifact_store_id == nil do
      Logger.info("Creating artifact store for #{project.id}")

      :ok = Projecthub.Artifact.create_for_project(project.id)
    else
      :ok
    end
  end

  defp analyze_repository(_project, _repository) do
    :ok
  end

  defp check_collaborators(_repository) do
    :ok
  end

  defp handle_all_errors(cb) do
    cb.()
  rescue
    e ->
      Logger.error("Error #{inspect(e)}")
      {:error, e}
  end
end
