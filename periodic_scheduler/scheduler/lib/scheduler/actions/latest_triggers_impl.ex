defmodule Scheduler.Actions.LatestTriggersImpl do
  @moduledoc """
  Module serves to find one latest trigger for each periodic which ID is given in
  the request IDs list.
  """

  alias Util.ToTuple
  alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggersQueries, as: PTQueries

  def latest_triggers(params) do
    with {:ok, periodic_ids} <- non_empty_list_in_request(params),
         {:ok, triggers} <- PTQueries.get_latest_triggers(periodic_ids) do
      %{"triggers" => triggers} |> ToTuple.ok()
    end
  end

  defp non_empty_list_in_request(%{periodic_ids: []}) do
    "Parameter 'periodic_ids' can not be an empty list."
    |> ToTuple.error(:INVALID_ARGUMENT)
  end

  defp non_empty_list_in_request(%{periodic_ids: ids}), do: {:ok, ids}
end
