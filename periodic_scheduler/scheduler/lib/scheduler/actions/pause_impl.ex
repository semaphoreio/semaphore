defmodule Scheduler.Actions.PauseImpl do
  @moduledoc """
  Module serves to pause given scheduler so it won't schedule any workflows until
  it is unpaused.
  """

  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.Workers.QuantumScheduler
  alias LogTee, as: LT
  alias Util.ToTuple

  def pause(params) do
    with {:ok, periodic} <- get_periodic(params),
         false <- already_paused?(periodic) do
      pause_periodic(periodic, params.requester)
    end
  end

  defp pause_periodic(periodic, requester) do
    with {:ok, periodic} <- PeriodicsQueries.pause(periodic, requester),
         :ok <- delete_quantum_job(periodic.id) do
      {:ok, "Scheduler was paused successfully."}
    else
      error ->
        error |> LT.warn("Error while trying to pause periodic #{periodic.id} ")
        "Error while pausing the scheduler." |> ToTuple.error(:INTERNAL)
    end
  end

  defp delete_quantum_job(id) do
    id |> String.to_atom() |> QuantumScheduler.delete_job()
  end

  defp already_paused?(%{paused: true}), do: {:ok, "Scheduler was paused successfully."}
  defp already_paused?(_periodic), do: false

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
