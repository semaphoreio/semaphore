defmodule Projecthub.Models.PeriodicTask do
  alias Projecthub.Models.PeriodicTask.{Definition, GRPC, YAML}
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

  def update_all(%Project{} = project, new_tasks, requester_id) do
    definitions = Enum.map(new_tasks, &to_periodic_definition/1)

    Logger.info(
      "PeriodicTask.update_all dispatching to bulk_upsert_and_prune: " <>
        "project_id=#{project.id} requester_id=#{requester_id} tasks=#{length(definitions)}"
    )

    case GRPC.bulk_upsert_and_prune(
           project.id,
           project.organization_id,
           requester_id,
           definitions
         ) do
      {:ok, %{upserted: upserted, deleted: deleted}} ->
        Logger.info(
          "PeriodicTask.update_all succeeded: project_id=#{project.id} " <>
            "upserted=#{length(upserted)} deleted=#{length(deleted)}"
        )

        {:ok, upserted: upserted, deleted: deleted}

      {:error, reason} ->
        Logger.error("Failed updating tasks for project #{project.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def delete_all(%Project{} = project, requester_id) do
    Logger.info("PeriodicTask.delete_all dispatching: project_id=#{project.id} requester_id=#{requester_id}")

    case GRPC.bulk_upsert_and_prune(project.id, project.organization_id, requester_id, []) do
      {:ok, %{deleted: deleted}} ->
        Logger.info("PeriodicTask.delete_all succeeded: project_id=#{project.id} deleted=#{length(deleted)}")

        {:ok, deleted}

      {:error, reason} ->
        Logger.error("Failed deleting tasks for project #{project.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp to_periodic_definition(%__MODULE__{} = task) do
    %{
      id: task.id || "",
      name: task.name || "",
      description: task.description || "",
      recurring: task.recurring,
      reference: Definition.format_branch_as_reference(task.branch),
      at: task.at || "",
      pipeline_file: task.pipeline_file || "",
      parameters: task.parameters || [],
      state: Definition.status_to_state(task.status)
    }
  end

  # Helper function to extract branch name from reference or fall back to branch field
  # This handles the transition from gRPC "branch" field to "reference" field
  defp extract_branch_from_reference_or_branch(%{reference: reference})
       when is_binary(reference) do
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
