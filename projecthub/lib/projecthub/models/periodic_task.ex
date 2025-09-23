defmodule Projecthub.Models.PeriodicTask do
  alias Projecthub.Models.PeriodicTask.{GRPC, YAML}
  alias Projecthub.Models.Project
  require Logger

  @fields ~w(id name description status recurring project_name
             branch pipeline_file at parameters)a
  defstruct @fields

  def construct(periodics_or_tasks, project_name) when is_list(periodics_or_tasks) do
    Enum.into(periodics_or_tasks, [], &construct(&1, project_name))
  end

  def construct(periodic_or_task, project_name) do
    parameters = Enum.into(periodic_or_task.parameters, [], &construct_parameter/1)
    status = construct_status(periodic_or_task)

    # Handle reference-to-branch mapping for gRPC responses
    branch = extract_branch_from_reference_or_branch(periodic_or_task)

    params =
      periodic_or_task
      |> Map.take(@fields)
      |> Map.put(:project_name, project_name)
      |> Map.put(:status, status)
      |> Map.put(:parameters, parameters)
      |> Map.put(:branch, branch)
      |> Map.merge(Map.new())

    struct!(__MODULE__, params)
  end

  defp construct_status(%{paused: true}), do: :STATUS_INACTIVE
  defp construct_status(%{paused: false}), do: :STATUS_ACTIVE
  defp construct_status(%{status: status}), do: status
  defp construct_status(_periodic_or_task), do: :STATUS_UNSPECIFIED

  defp construct_parameter(parameter),
    do: Map.take(parameter, ~w(name description required default_value options)a)

  def list(project) do
    case GRPC.list(project.id) do
      {:ok, tasks} ->
        {:ok, Enum.into(tasks, [], &construct(&1, project.name))}

      {:error, reason} ->
        Logger.error("Unable to list tasks for project #{project.id}")
        {:error, reason}
    end
  end

  def upsert(%__MODULE__{} = task, %Project{} = project, requester_id) do
    yaml_definition = YAML.compose(task, project)
    organization_id = project.organization_id

    case GRPC.upsert(yaml_definition, organization_id, requester_id) do
      {:ok, periodic_id} ->
        Logger.debug("Successfully applied task #{project.id}/#{task.name}")
        {:ok, periodic_id}

      {:error, reason} ->
        Logger.error("Failed applying task #{project.id}/#{task.name}: #{inspect(reason)}}")
        {:error, reason}
    end
  end

  def delete(%__MODULE__{} = task, requester_id) do
    case GRPC.delete(task.id, requester_id) do
      {:ok, periodic_id} ->
        Logger.debug("Successfully deleted task #{task.id}")
        {:ok, periodic_id}

      {:error, reason} ->
        Logger.error("Unable to delete task #{task.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def update_all(project, new_tasks, requester_id) do
    with {:ok, old_tasks} <- list(project),
         {tasks_to_upsert, tasks_to_delete} <-
           triage(old_tasks, new_tasks),
         {:ok, deleted_task_ids} <-
           apply_each(tasks_to_delete, &delete(&1, requester_id)),
         {:ok, upserted_task_ids} <-
           apply_each(tasks_to_upsert, &upsert(&1, project, requester_id)) do
      Logger.debug("Successfully updated all tasks for project #{project.id}")
      {:ok, upserted: upserted_task_ids, deleted: deleted_task_ids}
    else
      {:error, reason} ->
        Logger.error("Failed updating tasks for project #{project.id}: #{inspect(reason)}}")
        {:error, reason}
    end
  end

  defp triage(old_tasks, new_tasks) do
    new_task_ids = MapSet.new(new_tasks, & &1.id)
    {new_tasks, Enum.reject(old_tasks, &MapSet.member?(new_task_ids, &1.id))}
  end

  def delete_all(project, requester_id) do
    with {:ok, tasks} <- list(project),
         {:ok, task_ids} <- apply_each(tasks, &delete(&1, requester_id)) do
      Logger.debug("Successfully deleted all tasks for project #{project.id}")
      {:ok, task_ids}
    else
      {:error, reason} ->
        Logger.error("Failed deleting tasks for project #{project.id}: #{inspect(reason)}}")
        {:error, reason}
    end
  end

  defp apply_each(tasks, func) do
    Enum.reduce_while(tasks, {:ok, []}, fn task, {:ok, acc_ids} ->
      case func.(task) do
        {:ok, task_id} -> {:cont, {:ok, [task_id | acc_ids]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  # Helper function to extract branch name from reference or fall back to branch field
  # This handles the transition from gRPC "branch" field to "reference" field
  defp extract_branch_from_reference_or_branch(%{reference: reference}) when is_binary(reference) do
    extract_branch_name(reference)
  end

  defp extract_branch_from_reference_or_branch(%{branch: branch}) when is_binary(branch) do
    branch
  end

  defp extract_branch_from_reference_or_branch(_), do: nil

  # Helper function to extract branch name from Git reference format
  # "refs/heads/main" -> "main"
  # "refs/tags/v1.0" -> "refs/tags/v1.0"
  # "main" -> "main" (fallback for plain strings)
  defp extract_branch_name(reference) when is_binary(reference) do
    if String.starts_with?(reference, "refs/heads/") do
      String.replace_prefix(reference, "refs/heads/", "")
    else
      reference
    end
  end

  defp extract_branch_name(_), do: nil
end
