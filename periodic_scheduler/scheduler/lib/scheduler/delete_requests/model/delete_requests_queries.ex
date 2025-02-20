defmodule Scheduler.DeleteRequests.Model.DeleteRequestsQueries do
  @moduledoc """
  DeleteRequests Queries
  Operations on DeleteRequest  type
  """

  alias Scheduler.PeriodicsRepo, as: Repo
  alias Scheduler.DeleteRequests.Model.DeleteRequests
  alias LogTee, as: LT
  alias Util.ToTuple

  @doc """
  Inserts new DeleteRequest into DB
  """
  def insert(request) do
    params =
      request
      |> Map.put(:periodic_id, request.id)
      |> Map.drop([:id])

    %DeleteRequests{}
    |> DeleteRequests.changeset(params)
    |> Repo.insert()
    |> process_response()
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  defp process_response({:ok, del_req}) do
    del_req |> LT.info("Persisted delete_request: ") |> ToTuple.ok()
  end

  defp process_response(error_response) do
    error_response |> LT.warn("Error while persisting delete_request: ")
  end
end
