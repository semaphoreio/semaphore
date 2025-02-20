defmodule SemaphoreYamlSpec.Validator do

  @header "header-v1.0"

  def validate(full_path) do
    with  {:ok, config} <- parse_yml_file(full_path),
          :ok <- validate_header(config),
          apiVersion = Map.get(config, "apiVersion"),
          body = Map.get(config, "spec"),
          file_name = full_path |> String.split("/") |> Enum.at(-1) do
      validate_body(apiVersion, body)
      |> write2file(file_name)
    end
  end

  defp validate_header(config), do: validate(@header, config)

  defp validate_body(version, body), do: validate(version, body)

  def validate(schema_version, config) do
    with {:ok, schema} <- schema_version |> schema_name() |> parse_yml_file(),
    do: validate_(schema, config)
  end

  def validate_(schema, config) do
    schema
    |> ExJsonSchema.Schema.resolve
    |> ExJsonSchema.Validator.validate(config)
  end

  def parse_yml_file(file) do
    try do
      File.stat!(file)
      YamlElixir.read_from_file(file)
    rescue error ->
      {:error, {file, error}}
    catch a, b ->
      {:error, {file, {a, b}}}
    end
    # |> IO.inspect
  end

  @json_schema_dir :code.priv_dir(:spec)

  defp schema_name(version),
    do: Path.join(@json_schema_dir, '#{version}.yml')

  defp write2file(content, file) do
    out_path = "test_output"
    File.mkdir_p(out_path)
    File.write("#{out_path}/#{file}", inspect(content, pretty: true))
    content
  end
end
