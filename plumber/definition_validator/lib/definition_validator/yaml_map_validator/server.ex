defmodule DefinitionValidator.YamlMapValidator.Server do
  @moduledoc false

  alias DefinitionValidator.YamlMapValidator.Impl

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %{}, [name: __MODULE__])
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call(:show_schemas, _from, schemas) do
    {:reply, schemas, schemas}
  end

  def handle_call({:validate, config}, from, schemas) do
    Impl.validate(config, schemas, from)
  end

  def handle_call({:cache_schema, version}, _from, schemas) do
    case Impl.cache_schema(schemas, version) do
      {:ok, new_schemas} = response ->
        {:reply, response, new_schemas}
      error ->
        {:reply, error, schemas}
    end
  end
end
