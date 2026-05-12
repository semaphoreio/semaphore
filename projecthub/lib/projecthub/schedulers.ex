defmodule Projecthub.Schedulers do
  alias Projecthub.Models.Scheduler
  alias Crontab.CronExpression.Parser

  @validators [
    &__MODULE__.validate_cron/1
  ]

  def update(project, schedulers, requester_id) do
    if System.get_env("SKIP_SCHEDULERS") == "true" do
      {:ok, nil}
    else
      do_update(project, schedulers, requester_id)
    end
  end

  defp do_update(project, schedulers, requester_id) do
    with :ok <- validate_schedulers(schedulers),
         {:ok, existing_schedulers} <- Scheduler.list(project) do
      {to_delete, to_apply} = triage_for_update(schedulers, existing_schedulers)

      with :ok <- delete_each(to_delete, requester_id),
           :ok <- apply_each(to_apply, project, requester_id) do
        {:ok, nil}
      end
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

  defp validate_schedulers(schedulers) do
    Enum.reduce_while(schedulers, :ok, fn scheduler, _acc ->
      case run_validators(scheduler, @validators) do
        :ok -> {:cont, :ok}
        err -> {:halt, err}
      end
    end)
  end

  defp run_validators(scheduler, validators) do
    Enum.reduce_while(validators, :ok, fn validator, _acc ->
      case validator.(scheduler) do
        :ok -> {:cont, :ok}
        err -> {:halt, err}
      end
    end)
  end

  def validate_cron(%{at: at, name: name}) do
    case Parser.parse(at) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        {:error, "Invalid cron expression in task '#{name}': #{inspect(reason)}"}
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
