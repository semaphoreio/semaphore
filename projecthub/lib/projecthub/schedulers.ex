defmodule Projecthub.Schedulers do
  alias Projecthub.Models.PeriodicTask.GRPC, as: PeriodicSchedulerClient

  def update(project, schedulers, requester_id) do
    if System.get_env("SKIP_SCHEDULERS") == "true" do
      {:ok, nil}
    else
      do_update(project, schedulers, requester_id)
    end
  end

  defp do_update(project, schedulers, requester_id) do
    definitions = Enum.map(schedulers, &to_periodic_definition/1)

    case PeriodicSchedulerClient.bulk_upsert_and_prune(
           project.id,
           project.organization_id,
           requester_id,
           definitions
         ) do
      {:ok, _} -> {:ok, nil}
      err -> err
    end
  end

  defp delete_each(schedulers, requester_id) do
    Enum.reduce_while(schedulers, :ok, fn scheduler, _acc ->
      case Scheduler.delete(scheduler, requester_id) do
        {:ok, _} -> {:cont, :ok}
        err -> {:halt, err}
      end
    end)
  end

  defp apply_each(schedulers, project, requester_id) do
    Enum.reduce_while(schedulers, :ok, fn scheduler, _acc ->
      case Scheduler.apply(scheduler, project, requester_id) do
        {:ok, _} -> {:cont, :ok}
        err -> {:halt, err}
      end
    end)
  end

  def delete_all(project, requester_id) do
    case PeriodicSchedulerClient.bulk_upsert_and_prune(
           project.id,
           project.organization_id,
           requester_id,
           []
         ) do
      {:ok, _} -> {:ok, nil}
      err -> err
    end
  end

  defp to_periodic_definition(scheduler) do
    %{
      id: scheduler.id || "",
      name: scheduler.name || "",
      description: "",
      recurring: true,
      reference: format_branch_as_reference(scheduler.branch),
      at: scheduler.at || "",
      pipeline_file: scheduler.pipeline_file || "",
      parameters: [],
      state: status_to_state(scheduler.status)
    }
  end

  defp status_to_state(:STATUS_ACTIVE), do: :ACTIVE
  defp status_to_state(:STATUS_INACTIVE), do: :PAUSED
  defp status_to_state(_), do: :UNCHANGED

  defp format_branch_as_reference("refs/tags/" <> _ = tag), do: tag
  defp format_branch_as_reference("refs/pull/" <> _ = pr), do: pr

  defp format_branch_as_reference(branch_name) when is_binary(branch_name) and branch_name != "",
    do: "refs/heads/#{branch_name}"

  defp format_branch_as_reference(_), do: "refs/heads/master"
end
