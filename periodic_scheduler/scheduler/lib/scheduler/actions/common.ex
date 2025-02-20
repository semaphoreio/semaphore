defmodule Scheduler.Actions.Common do
  @moduledoc """
  Module serves to provide common functions for actions.
  """
  alias Util.ToTuple

  def non_empty_value_or_default(map, key, default) do
    case Map.get(map, key) do
      val when is_integer(val) and val > 0 -> {:ok, val}
      val when is_binary(val) and val != "" -> {:ok, val}
      val when is_atom(val) -> {:ok, val}
      _ -> {:ok, default}
    end
  end

  def either_project_or_org_id_present(:skip, :skip) do
    "Either 'organization_id' or 'project_id' parameters are required."
    |> ToTuple.error(:INVALID_ARGUMENT)
  end

  def either_project_or_org_id_present(_project_id, _org_id), do: true
end
