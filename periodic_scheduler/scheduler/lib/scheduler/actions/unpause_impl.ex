defmodule Scheduler.Actions.UnpauseImpl do
  @moduledoc """
  Module serves to unpause given scheduler so it can resume scheduling workflows.
  """

  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.Workers.QuantumScheduler
  alias Crontab.Scheduler, as: CronEval
  alias Crontab.CronExpression.Parser
  alias LogTee, as: LT
  alias Util.ToTuple

  def unpause(params) do
    with {:ok, periodic} <- get_periodic(params),
         false <- suspended?(periodic),
         true <- is_paused?(periodic),
         true <- cron_valid?(periodic) do
      unpause_periodic(periodic, params.requester)
    end
  end

  defp unpause_periodic(periodic, requester) do
    with {:ok, periodic} <- PeriodicsQueries.unpause(periodic, requester),
         {:recurring, true} <- is_recurring?(periodic),
         {:ok, _job} <- QuantumScheduler.start_periodic_job(periodic) do
      {:ok, "Scheduler was unpaused successfully."}
    else
      {:recurring, false} ->
        {:ok, "Scheduler was unpaused successfully."}

      error ->
        error |> LT.warn("Error while trying to unpause periodic #{periodic.id} ")
        "Error while unpausing the scheduler." |> ToTuple.error(:INTERNAL)
    end
  end

  defp suspended?(%{suspended: true}),
    do: "The organization is supended." |> ToTuple.error(:FAILED_PRECONDITION)

  defp suspended?(_periodic), do: false

  defp is_paused?(%{paused: true}), do: true
  defp is_paused?(_false), do: {:ok, "Scheduler was unpaused successfully."}

  defp is_recurring?(%{recurring: true}), do: {:recurring, true}
  defp is_recurring?(_false), do: {:recurring, false}

  defp cron_valid?(%{recurring: false}), do: true

  defp cron_valid?(periodic) do
    case Parser.parse(periodic.at) do
      {:ok, cron_exp} ->
        cron_exp |> CronEval.get_next_run_date() |> cron_eval_check()

      _error ->
        "The cron expression is invalid and must be corrected first."
        |> ToTuple.error(:FAILED_PRECONDITION)
    end
  end

  defp cron_eval_check({:ok, _next_date}), do: true

  defp cron_eval_check(_error) do
    "The cron expression is invalid and must be corrected first."
    |> ToTuple.error(:FAILED_PRECONDITION)
  end

  defp get_periodic(%{id: id, requester: user})
       when id != "" and user != "" do
    case PeriodicsQueries.get_by_id(id) do
      {:error, _msg} ->
        "Scheduler with id:'#{id}' not found." |> ToTuple.error(:NOT_FOUND)

      response ->
        response
    end
  end

  defp get_periodic(%{id: ""}),
    do: "The 'id' parameter can not be empty string." |> ToTuple.error(:INVALID_ARGUMENT)

  defp get_periodic(%{requester: ""}),
    do: "The 'requester' parameter can not be empty string." |> ToTuple.error(:INVALID_ARGUMENT)
end
