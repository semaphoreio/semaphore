defmodule Scheduler.Actions.HistoryImpl do
  @moduledoc """
  Module serves to form history of triggers for given periodic.
  """

  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.Periodics.Model.Periodics
  alias Scheduler.PeriodicsTriggers.Model.HistoryPage
  alias Scheduler.Utils.GitReference

  def history(params) do
    {:ok, handle_history(params)}
  rescue
    error in GRPC.RPCError ->
      {:error, {error.status, error.message}}
  end

  def handle_history(params) do
    if empty?(params.periodic_id) do
      raise_error(:invalid_argument, "Missing argument: periodic_id")
    end

    case PeriodicsQueries.get_by_id(params.periodic_id) do
      {:ok, periodic = %Periodics{}} -> periodic
      _ -> raise_error(:not_found, "Periodic '#{params.periodic_id}' not found.")
    end

    history_page =
      HistoryPage.load(params.periodic_id,
        cursor_type: params.cursor_type,
        cursor_value: params.cursor_value,
        filters: parse_filters(params.filters)
      )

    %{
      triggers: Enum.into(history_page.results, [], &from_model/1),
      cursor_before: history_page.cursor_before || 0,
      cursor_after: history_page.cursor_after || 0
    }
  end

  defp empty?(nil), do: true
  defp empty?(""), do: true
  defp empty?([]), do: true
  defp empty?(_), do: false

  defp raise_error(error, message) do
    raise GRPC.RPCError,
      status: apply(GRPC.Status, error, []),
      message: message
  end

  defp parse_filters(filters) when is_map(filters) do
    filter_keys = ~w(branch_name pipeline_file triggered_by)a

    filters
    |> Map.take(filter_keys)
    |> Enum.reject(&empty?(elem(&1, 1)))
    |> Enum.map(&transform_filter/1)
    |> Map.new()
  end

  defp parse_filters(_filters), do: %{}

  defp transform_filter({:branch_name, value}) do
    normalized_ref = GitReference.normalize(value)
    short_name = GitReference.extract_name(value)
    {:reference, %{normalized: normalized_ref, short: short_name, original: value}}
  end

  defp transform_filter(filter), do: filter

  defp from_model(periodics_trigger) do
    parameter_values = Enum.into(periodics_trigger.parameter_values, [], &Map.from_struct/1)
    periodics_trigger |> Map.from_struct() |> Map.put(:parameter_values, parameter_values)
  end
end
