defmodule Ppl.Query2Ecto.STM do
  @moduledoc """
  Convert Repo.query() response to format sutable for STM.enter_scheduling()
  """

  alias Ppl.EctoRepo, as: Repo

  def load({:ok, %{columns: columns, rows: rows}}, ecto_type) do
    {:ok, Enum.map(rows, &updated_map2ecto(columns, &1, ecto_type))}
  end
  def load(error, _), do: error

  defp updated_map2ecto(columns, row, ecto_type) do
    with sql_response <- columns |> Enum.zip(row) |> Enum.into(%{}),
      old_update_time <- sql_response["old_update_time"],
      ecto_new when is_map(ecto_new) <- to_ecto(sql_response, ecto_type),
      ecto_old when is_map(ecto_new) <-
        sql_response |> Map.put("updated_at", old_update_time) |> to_ecto(ecto_type),
    do: {ecto_old, ecto_new}
  end

  defp to_ecto(map, ecto_type) when is_map(map), do: ecto_type |> Repo.load(map)
end
