defmodule DefinitionValidator.YamlMapValidator.Server do
  @moduledoc """
  Caches schemas and validates definitions against them
  """

  alias DefinitionValidator.YamlMapValidator.Impl

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call(:show_schemas, _from, schemas) do
    {:reply, schemas, schemas}
  end

  def handle_call({:validate, schema_version, definition}, from, schemas) do
    Impl.validate(schema_version, definition, schemas, from)
  end

  def handle_call({:cache_schema, version}, _from, schemas) do
    case Impl.cache_schema(schemas, version) do
      response = {:ok, new_schemas} ->
        {:reply, response, new_schemas}

      error ->
        {:reply, error, schemas}
    end
  end
end
