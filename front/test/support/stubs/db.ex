defmodule Support.Stubs.DB.NotFoundError do
  defexception message: "Record not found"
end

defmodule Support.Stubs.DB do
  require Logger
  alias Support.Stubs.DB.State

  def init, do: State.init()
  def schemas, do: State.schemas()
  def tables, do: State.tables()
  def table_exists?(table_name), do: Enum.member?(tables(), table_name)

  def reset do
    schemas()
    |> Enum.map(fn {k, _} -> {k, []} end)
    |> Enum.into(%{})
    |> State.update_tables()
  end

  def add_table(name, schema) do
    verify_table_doesnt_exists!(name)

    schemas() |> Map.merge(%{name => schema}) |> State.update_schemas()
    tables() |> Map.merge(%{name => []}) |> State.update_tables()
  end

  #
  # Query interface
  #

  def all(table) do
    verify_table_exists!(table)

    Map.get(tables(), table)
  end

  def first(table) do
    all(table) |> List.first()
  end

  def last(table) do
    all(table) |> List.last()
  end

  def all(table, column) do
    all(table) |> Enum.map(fn e -> Map.get(e, column) end)
  end

  def find(table, value) do
    find_by(table, :id, value)
  end

  def find_many(table, ids) do
    all(table) |> Enum.filter(fn e -> Enum.member?(ids, e.id) end)
  end

  def find_by(table, column, value) do
    case find_all_by(table, column, value) do
      [] -> nil
      entries -> hd(entries)
    end
  end

  def find_by!(table, column, value) do
    case find_by(table, column, value) do
      nil -> not_found!(table, column, value)
      record -> record
    end
  end

  def find_all_by(table, column, value) do
    all(table) |> Enum.filter(fn e -> Map.get(e, column) == value end)
  end

  def filter(table, filters) when is_list(filters) or is_map(filters) do
    filters
    |> Enum.reduce(all(table), fn
      {column, value}, results ->
        results
        |> Enum.filter(fn item -> Map.get(item, column) == value end)
    end)
  end

  def filter(table, filter_func) when is_function(filter_func, 1) do
    all(table)
    |> Enum.filter(&filter_func.(&1))
  end

  def insert(table, entry) do
    verify_insert!(table, entry)

    State.insert_entry(table, entry)
  end

  def upsert(table, entry, field \\ :id) do
    case find_by(table, field, Map.get(entry, field)) do
      nil -> insert(table, entry)
      _ -> update(table, entry, field)
    end
  end

  def extract(entries, column) when is_list(entries) do
    Enum.map(entries, fn e -> Map.get(e, column) end)
  end

  def extract(entry, column) do
    Map.get(entry, column)
  end

  def update(table, new_entry, field \\ :id) do
    verify_insert!(table, new_entry)

    State.update_entry(table, new_entry, field)
  end

  def delete(table, callback) when is_function(callback) do
    verify_table_exists!(table)

    State.delete_entries(table, callback)
  end

  def delete(table, entry_id) do
    delete(table, fn e -> e.id == entry_id end)
  end

  def clear(table) do
    verify_table_exists!(table)

    State.clear_table(table)
  end

  #
  # Failures
  #

  defp verify_insert!(table_name, entry) do
    verify_table_exists!(table_name)
    verify_entry_matches_schema!(table_name, entry)
  end

  defp verify_entry_matches_schema!(table_name, entry) do
    schema = schemas() |> Map.get(table_name)

    Enum.each(entry, fn {k, _} ->
      if !Enum.member?(schema, k) do
        raise "Stub #{schema} has no #{k}. Available fields #{inspect(schema)}"
      end
    end)

    Enum.each(schema, fn field ->
      if !Map.has_key?(entry, field) do
        raise "Missing field #{field} in #{table_name} stub. #{inspect(entry)}"
      end
    end)
  end

  defp verify_table_exists!(table_name) do
    unless Map.has_key?(schemas(), table_name) do
      inspected_schema = schemas() |> inspect(pretty: true)

      msg1 = "Stub for '#{table_name}' does not exists"
      msg2 = "The Stubs schema has the following tables #{inspected_schema}"

      raise "#{msg1}. #{msg2}"
    end
  end

  defp verify_table_doesnt_exists!(table_name) do
    if Map.has_key?(schemas(), table_name) do
      inspected_schema = schemas() |> inspect(pretty: true)

      msg1 = "Stub for '#{table_name}' already exists"
      msg2 = "The Stubs schema has the following tables #{inspected_schema}"

      raise "#{msg1}. #{msg2}"
    end
  end

  defp not_found!(table, column, value) do
    msg = "Entry in stub table '#{table}' where #{column}=#{inspect(value)} not found."

    Logger.debug(fn ->
      "#{msg}. Existing values #{all(table, column) |> Enum.join(", ")}"
    end)

    raise Support.Stubs.DB.NotFoundError, msg
  end

  defmodule State do
    @moduledoc """
    Represents the internal state of the DB.
    """

    def init do
      state = %{schemas: Map.new(), tables: Map.new()}

      Agent.start_link(fn -> state end, name: __MODULE__)
    end

    def tables, do: Agent.get(__MODULE__, fn db -> db.tables end)
    def schemas, do: Agent.get(__MODULE__, fn db -> db.schemas end)

    def update_tables(new_tables) do
      Agent.update(__MODULE__, fn db -> %{db | tables: new_tables} end)
    end

    def update_schemas(new_schemas) do
      Agent.update(__MODULE__, fn db -> %{db | schemas: new_schemas} end)
    end

    def insert_entry(table, entry) do
      Agent.get_and_update(__MODULE__, fn db ->
        current_table = Map.get(db.tables, table, [])
        new_table = current_table ++ [entry]
        new_tables = Map.put(db.tables, table, new_table)

        {entry, %{db | tables: new_tables}}
      end)
    end

    def update_entry(table, entry, field) do
      Agent.get_and_update(__MODULE__, fn db ->
        current_table = Map.get(db.tables, table, [])

        new_table =
          Enum.map(current_table, fn old_entry ->
            if Map.get(old_entry, field) == Map.get(entry, field) do
              entry
            else
              old_entry
            end
          end)

        new_tables = Map.put(db.tables, table, new_table)

        {entry, %{db | tables: new_tables}}
      end)
    end

    def delete_entries(table, filter_fn) do
      Agent.get_and_update(__MODULE__, fn db ->
        current_table = Map.get(db.tables, table, [])
        new_table = Enum.reject(current_table, filter_fn)
        new_tables = Map.put(db.tables, table, new_table)

        {:ok, %{db | tables: new_tables}}
      end)
    end

    def clear_table(table) do
      Agent.get_and_update(__MODULE__, fn db ->
        new_tables = Map.put(db.tables, table, [])

        {:ok, %{db | tables: new_tables}}
      end)
    end
  end
end
