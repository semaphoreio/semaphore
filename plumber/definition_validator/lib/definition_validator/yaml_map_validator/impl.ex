defmodule DefinitionValidator.YamlMapValidator.Impl do
  @moduledoc """
  Validate pipeline definition against json schema specification.
  """

  alias DefinitionValidator.YamlMapValidator.Server

  def validate(ppl_def, schemas, from) do
    case get_config_version(ppl_def) do
      {:ok, version} ->
        validate_(version in Map.keys(schemas), version, ppl_def, schemas, from)
      error ->
        {:reply, error, schemas}
    end
  end

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
    {:ok, YamlElixir.read_from_file(file_name)}
  rescue error ->
    {:error, {:malformed, {file_name, error}}}
  catch a, b ->
    {:error, {:malformed, {file_name, {a, b}}}}
  end
  defp parse_yml_file(error), do: error

  defp get_config_version(ppl_def), do:
    ppl_def |> Map.get("version") |> validate_version()

  defp validate_version(version) when is_binary(version), do: {:ok, version}
  defp validate_version(_), do:
    {:error, {:malformed, "Required property 'version' missing or not string"}}

  defp validate_(_schema_cached? = true, version, ppl_def, schemas, _from) do
    with schema  <- Map.get(schemas, version),
         :ok     <- validate_with_ex_json_schema(schema, ppl_def)
    do
      {:reply, {:ok, ppl_def}, schemas}
    else
      {:error, e} ->
        response = {:error, {:malformed, e}}
        {:reply, response, schemas}
      error ->
        response = {:error, {:malformed, error}}
        {:reply, response, schemas}
    end
  end
  defp validate_(_schema_cached? = false, version, ppl_def, schemas, from) do
    delegate_request(from, version, ppl_def)

    {:noreply, schemas}
  end


  defp validate_with_ex_json_schema(schema, ppl_def) do
    schema
    |> ExJsonSchema.Schema.resolve
    |> ExJsonSchema.Validator.validate(ppl_def)
  end

  defp delegate_request(from, version, ppl_def) do
    spawn_link(fn ->
      result =
        with  {:ok, _} <- GenServer.call(Server, {:cache_schema, version}),
        do:   GenServer.call(Server, {:validate, ppl_def})

      GenServer.reply(from, result)
    end)
  end
end
