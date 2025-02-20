defmodule Scheduler.Actions.DeleteImpl do
  @moduledoc """
  Module serves to find periodic given id or org_id and name and delete it and all
  related data (triggers and quantum job)
  """

  alias Util.ToTuple
  alias Ecto.Multi
  alias Scheduler.Workers.QuantumScheduler
  alias Scheduler.PeriodicsRepo, as: Repo
  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.DeleteRequests.Model.DeleteRequestsQueries

  def delete(params) do
    with {:ok, periodic} <- get_periodic(params),
         {:ok, _result} <- delete_in_transaction(periodic, params),
         :ok <- delete_quantum_job(periodic.id) do
      {:ok, "Periodic #{periodic.name} with id #{periodic.id} was successfully deleted."}
    end
  end

  defp get_periodic(%{id: id}) when id != "" do
    case PeriodicsQueries.get_by_id(id) do
      {:error, msg} -> msg |> ToTuple.error(:NOT_FOUND)
      response -> response
    end
  end

  defp get_periodic(_),
    do: "All search parameters in request are empty strings." |> ToTuple.error(:INVALID_ARGUMENT)

  defp delete_in_transaction(periodic, params) do
    Multi.new()
    # insert delete request
    |> Multi.run(:delete_req, fn _, _ ->
      DeleteRequestsQueries.insert(params)
    end)
    # cascade delete periodic and its triggers
    |> Multi.run(:periodic_delete, fn _, _ ->
      PeriodicsQueries.delete(periodic.id)
    end)
    # Run transaction
    |> Repo.transaction()
  end

  defp delete_quantum_job(id) do
    id |> String.to_atom() |> QuantumScheduler.delete_job()
  end
end
