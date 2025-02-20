defmodule Scheduler.Actions.DescribeImpl do
  @moduledoc """
  Module serves to form description for periodic with geven id or org_id and name.
  """

  alias Util.ToTuple
  alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggersQueries
  alias Scheduler.Periodics.Model.PeriodicsQueries

  def describe(params) do
    with {:ok, periodic} <- get_periodic_desc(params),
         {:ok, triggers} <- PeriodicsTriggersQueries.get_n_by_periodic_id(periodic.id, 10) do
      parameters = Enum.into(periodic.parameters, [], &Map.from_struct/1)

      %{
        periodic: periodic |> Map.from_struct() |> Map.put(:parameters, parameters),
        triggers:
          triggers
          |> Enum.map(fn tr ->
            parameter_values = Enum.into(tr.parameter_values, [], &Map.from_struct/1)
            tr |> Map.from_struct() |> Map.put(:parameter_values, parameter_values)
          end)
      }
      |> ToTuple.ok()
    end
  end

  defp get_periodic_desc(%{id: id}) when id != "" do
    case PeriodicsQueries.get_by_id(id) do
      {:error, msg} -> msg |> ToTuple.error(:NOT_FOUND)
      response -> response
    end
  end

  defp get_periodic_desc(_),
    do: "All search parameters in request are empty strings." |> ToTuple.error(:INVALID_ARGUMENT)
end
