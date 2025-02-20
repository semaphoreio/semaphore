defmodule Support.MemoryDb do
  use Agent

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)

    Agent.start_link(fn -> %{} end, name: name)
  end

  def all(db_name \\ __MODULE__, table) do
    db_name
    |> Agent.get(fn state ->
      state
      |> fetch_table(table)
    end)
    |> Enum.map(fn {_id, record} -> record end)
  end

  def get(db_name \\ __MODULE__, table, id) do
    db_name
    |> Agent.get(fn state ->
      state
      |> fetch_table(table)
    end)
    |> Enum.find_value(fn
      {^id, record} -> record
      _ -> nil
    end)
  end

  def add(db_name \\ __MODULE__, table_name, new_record) do
    internal_id = Map.get(new_record, :id, Ecto.UUID.generate())
    new_record = Map.put(new_record, :id, internal_id)

    :ok =
      db_name
      |> Agent.update(fn state ->
        table =
          state
          |> fetch_table(table_name)

        table =
          table
          |> Enum.find_index(fn
            {^internal_id, _element} ->
              true

            _ ->
              false
          end)
          |> case do
            nil ->
              [{internal_id, new_record} | table]

            idx ->
              List.replace_at(table, idx, {internal_id, new_record})
          end

        state
        |> Map.put(table_name, table)
      end)

    new_record
  end

  def find(db_name \\ __MODULE__, table_name, predicate) when is_function(predicate, 1) do
    all(db_name, table_name)
    |> Enum.find(&predicate.(&1))
  end

  defp fetch_table(state, table) do
    state
    |> Map.get(table, [])
  end
end
