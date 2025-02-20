defmodule DefinitionValidator.YamlMapValidator.Impl do
  @moduledoc """
  Validate definition against json schema specification.
  """

  alias DefinitionValidator.YamlMapValidator.Server

  @doc """
  Retreives and stores in cache given verision of schema
  """
  def cache_schema(schemas, v, spec_getter \\ &specification_get/1), do:
    if(v in Map.keys(schemas), do:
      {:ok, schemas}, else: insert_schema(schemas, v, spec_getter))

  defp insert_schema(schemas, version, spec_getter) do
    with {:ok, schema} <- spec_getter.(version),
    do: {:ok, Map.put(schemas, version, schema)}
  end

  defp specification_get(version), do:
    version |> schema_file_name() |> schema_file_exists() |> parse_yml_file()

  defp schema_file_name(version),
    do: {version, Path.join(json_schema_dir(), '#{version}.yml')}

  defp schema_file_exists({version, file_path}) do
    case File.stat(file_path) do
      {:error, _} -> {:error, {:malformed, "Version: '#{version}' is not supported!"}}
      {:ok, _} -> {:ok, file_path}
    end
  end

  defp json_schema_dir, do: :code.priv_dir(:spec)

  defp parse_yml_file({:ok, file_name}) do
    YamlElixir.read_from_file(file_name)
  rescue error ->
    {:error, {:malformed, {file_name, error}}}
  catch a, b ->
    {:error, {:malformed, {file_name, {a, b}}}}
  end
  defp parse_yml_file(error), do: error

  @doc """
  Validates given definition against given version of schema
  """
  def validate(schema_key, definition, schemas, from) do
    schema_key
    |> Kernel.in(Map.keys(schemas))
    |> validate_(schema_key, definition, schemas, from)
  end

  defp validate_(_schema_cached? = true, version, definition, schemas, _from) do
    with schema  <- Map.get(schemas, version),
         :ok     <- validate_with_ex_json_schema(schema, definition)
    do
      {:reply, {:ok, definition}, schemas}
    else
      {:error, e} ->
        response = {:error, {:malformed, e}}
        {:reply, response, schemas}
      error ->
        response = {:error, {:malformed, error}}
        {:reply, response, schemas}
    end
  end
  defp validate_(_schema_cached? = false, version, definition, schemas, from) do
    delegate_request(from, version, definition)

    {:noreply, schemas}
  end


  defp validate_with_ex_json_schema(schema, definition) do
    schema
    |> ExJsonSchema.Schema.resolve
    |> ExJsonSchema.Validator.validate(definition)
  end

  defp delegate_request(from, version, definition) do
    spawn_link(fn ->
      result =
        with  {:ok, _} <- GenServer.call(Server, {:cache_schema, version}),
        do:   GenServer.call(Server, {:validate, version, definition})

      GenServer.reply(from, result)
    end)
  end
end
