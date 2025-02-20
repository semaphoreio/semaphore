defmodule Projecthub.Schedulers do
  alias Projecthub.Models.Scheduler

  def update(project, schedulers, requester_id) do
    if System.get_env("SKIP_SCHEDULERS") == "true" do
      {:ok, nil}
    else
      do_update(project, schedulers, requester_id)
    end
  end

  defp do_update(project, schedulers, requester_id) do
    {:ok, existing_schedulers} = Scheduler.list(project)

    {schedulers_to_delete, schedulers_to_update_or_create} = triage_for_update(schedulers, existing_schedulers)

    with :ok <-
           schedulers_to_delete
           |> Enum.reduce_while(:ok, fn scheduler, _acc ->
             case Scheduler.delete(scheduler, requester_id) do
               {:ok, _} -> {:cont, :ok}
               err -> {:halt, err}
             end
           end),
         :ok <-
           schedulers_to_update_or_create
           |> Enum.reduce_while(:ok, fn scheduler, _acc ->
             case Scheduler.apply(scheduler, project, requester_id) do
               {:ok, _} -> {:cont, :ok}
               err -> {:halt, err}
             end
           end) do
      {:ok, nil}
    else
      err ->
        err
    end
  end

  def delete_all(project, requester_id) do
    {:ok, existing_schedulers} = Scheduler.list(project)

    existing_schedulers
    |> Enum.each(fn scheduler ->
      Scheduler.delete(scheduler, requester_id)
    end)

    {:ok, nil}
  end

  # we apply changes to all schedulers, no matter if there
  # is a change, should check if there is a change to update
  defp triage_for_update(schedulers, existing_schedulers) do
    schedulers_to_delete =
      existing_schedulers
      |> Enum.filter(fn existing_scheduler ->
        !Enum.any?(schedulers, fn scheduler ->
          scheduler.id == existing_scheduler.id
        end)
      end)

    {schedulers_to_delete, schedulers}
  end
end
