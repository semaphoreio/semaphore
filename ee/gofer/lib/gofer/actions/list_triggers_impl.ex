defmodule Gofer.Actions.ListTriggersImpl do
  @moduledoc """
  Collects functions for listing switch targets trigger events.
  """

  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.TargetTrigger.Model.TargetTriggerQueries, as: TTQueries
  alias Util.ToTuple

  def list_triggers(switch_id, target_name, page, page_size) do
    with {:ok, _switch} <- SwitchQueries.get_by_id(switch_id),
         {:ok, result_page} <-
           TTQueries.list_triggers_for_target(switch_id, target_name, page, page_size),
         {:ok, list_result} <- format_list_result(result_page) do
      {:ok, list_result}
    else
      {:error, msg = "Switch with id " <> _rest} -> {:ok, {:NOT_FOUND, msg}}
      resp = {:error, _e} -> resp
      error -> {:error, error}
    end
  end

  defp format_list_result(result_page) do
    result_page
    |> Map.from_struct()
    |> Enum.map(fn {key, value} ->
      case key == :entries do
        true -> {:trigger_events, value}
        false -> {key, value}
      end
    end)
    |> Enum.into(%{})
    |> ToTuple.ok()
  end
end
