defmodule Support do
  require Logger

  alias E2E.Clients.Project
  alias E2E.Clients.Pipeline

  def prepare_project(name, repository_url, tasks \\ []) do
    Logger.info("Creating project with name=#{name}, url=#{repository_url}")

    with {:ok, _} <- Project.create(name: name, repository_url: repository_url, tasks: tasks),
         {:ok, project} <- wait_for_project(name) do
      {:ok, project}
    else
      e ->
        Logger.error(
          "Error creating project with name=#{name}, url=#{repository_url}: #{inspect(e)}"
        )

        {:error, e}
    end
  end

  def wait_for_project(name, retries \\ 10, sleep \\ 2000) do
    Enum.reduce_while(1..retries, nil, fn attempt, _acc ->
      if attempt >= retries do
        {:halt, {:error, "Project #{name} did not show up in time."}}
      else
        case Project.get(name) do
          {:ok, project} ->
            if project["metadata"]["name"] == name do
              #
              # Waiting an additional 10s to return because sometimes it takes
              # a few extra seconds for the project's artifact storage to be ready.
              #
              Process.sleep(10_000)

              {:halt, {:ok, project}}
            else
              Process.sleep(sleep)
              {:cont, nil}
            end

          {:error, :not_found} ->
            Process.sleep(sleep)
            {:cont, nil}

          e ->
            Logger.error("Error finding project #{name}: #{inspect(e)}")
            {:halt, {:error, "Project #{name} did not show up in time."}}
        end
      end
    end)
  end

  def wait_for_workflow_to_finish(workflow_id, retries \\ 30, sleep \\ 10000) do
    Enum.reduce_while(1..retries, nil, fn attempt, _acc ->
      if attempt >= retries do
        {:halt, {:error, "Workflow #{workflow_id} did not finish in time."}}
      else
        case Pipeline.list(workflow_id) do
          {:ok, pipelines} ->
            if Enum.all?(pipelines, &is_pipeline_done/1) do
              Logger.info("Workflow #{workflow_id} finished")
              {:halt, {:ok, pipelines}}
            else
              Logger.info("Waiting for workflow #{workflow_id} to finish...")
              Process.sleep(sleep)
              {:cont, nil}
            end

          {:error, :not_found} ->
            Logger.info("Workflow #{workflow_id} not found, retrying...")
            Process.sleep(sleep)
            {:cont, nil}

          e ->
            Logger.error("Error finding workflow #{workflow_id}: #{inspect(e)}")
            {:cont, nil}
        end
      end
    end)
  end

  defp is_pipeline_done(%{"state" => "DONE"}), do: true
  defp is_pipeline_done(_), do: false
end
