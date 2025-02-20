defmodule Front.Onboarding.Forking do
  require Logger

  alias Front.Cache
  alias Front.Models

  def fork(org_id, user_id, fork, uuid) do
    set_cache(uuid, {:ok, nil})

    case Models.Project.fork_and_create(
           org_id,
           user_id,
           fork
         ) do
      {:ok, project} ->
        Watchman.increment("example_projects.forking.success")

        set_cache(uuid, {:ok, {project.id, project.organization_id}}, :timer.minutes(10))

      {:error, msg} ->
        Watchman.increment("example_projects.forking.failure")

        Logger.info("Fork failed: #{org_id} #{inspect(fork)} #{uuid} Error: #{inspect(msg)}")

        set_cache(uuid, {:error, msg})
    end
  end

  def get_project(uuid) do
    case Cache.get(uuid) do
      {:not_cached, _} ->
        Watchman.increment("example_projects.get_project.failure")
        Logger.info("Get Project failed: not cached: #{uuid}")

        {:error,
         "There was a problem with forking the repository, please try again in a few minutes."}

      {:ok, data} ->
        case Cache.decode(data) do
          {:ok, nil} ->
            {:ok, nil}

          {:ok, {project_id, org_id}} ->
            {:ok, Models.Project.find_by_id(project_id, org_id)}

          {:ok, project_id} ->
            {:ok, Models.Project.find_by_id(project_id)}

          {:error, msg} ->
            Watchman.increment("example_projects.get_project.failure")
            Logger.info("Get Project failed: error: #{uuid} #{msg}")

            {:error,
             "There was a problem with forking the repository, please try again in a few minutes."}
        end
    end
  end

  def start_workflow(project) do
    if Front.Onboarding.ReadinessCheck.ready(project) do
      #
      # We are adding 3s delay before starting the workflow to ensure that
      # the cache user is created on the cache server.
      #
      :timer.sleep(3000)

      case Front.Models.RepoProxy.create(
             project.id,
             project.owner_id,
             project.id,
             project.integration_type
           ) do
        {:ok, resp} ->
          Watchman.increment("example_projects.starting_workflow.success")

          {:ok, %{workflow_id: resp.workflow_id, pipeline_id: resp.pipeline_id}}

        {:error, message} ->
          Watchman.increment("example_projects.starting_workflow.failure")

          Logger.info(
            "Start Workflow: #{project.organization_id} #{project.id} Error: #{inspect(message)}"
          )

          {:error,
           "There was a problem with starting the workflow, make sure that your fork has fork-and-run branch."}
      end
    else
      {:ok, :not_ready}
    end
  end

  defp set_cache(uuid, value, expiration \\ :timer.hours(48)) do
    case Cache.set(uuid, Cache.encode(value), expiration) do
      {:error, msg} ->
        Logger.info("Cache failed: #{uuid} Error: #{inspect(msg)}")

      _ ->
        nil
    end
  end
end
