defmodule SemaphoreYamlSpec.Validator do
  @moduledoc false

  def validate(full_path) do
    with  {:ok, {version, config}} <- get_config_file_version(full_path),
          file_name <- full_path |> String.split("/") |> Enum.at(-1),
    do:   version |> schema_file_name() |> validate(config, file_name) |> write2file(file_name)

  end
  def validate(schema_file, config, _pipeline_file) do
    with  {:ok, schema} <- parse_yml_file(schema_file),
    do: validate_(schema, config)
  end

  defp write2file(content, file) do
    out_path = "test_output"
    File.mkdir_p(out_path)
    File.write("#{out_path}/#{file}", inspect(content, pretty: true))
    content
  end

  def get_config_file_version(file) do
    with  {:ok, config} <- parse_yml_file(file),
          version when is_binary(version) <-
            Map.get(config, "version", {:error, "Required property 'version' missing"}),
    do: {:ok, {version, config}}
  end

  def validate_(schema, config) do
    schema
    |> ExJsonSchema.Schema.resolve
    |> ExJsonSchema.Validator.validate(config)

    # :jesse.validate_with_schema(schema, config)
    # :jesse.validate_with_schema(schema, config, [allowed_errors: :infinity])
    # :jesse.validate_with_schema(schema, config, [allowed_errors: 3])
  end

  def parse_yml_file(file) do
    try do
      {:ok, YamlElixir.read_from_file(file)}
    rescue error ->
      {:error, {file, error}}
    catch a, b ->
      {:error, {file, {a, b}}}
    end
    # |> IO.inspect
  end

  @json_schema_dir :code.priv_dir(:spec)
  defp schema_file_name(version), do: @json_schema_dir ++ '/#{version}.yml'
end
