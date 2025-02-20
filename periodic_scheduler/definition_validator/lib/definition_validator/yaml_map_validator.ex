defmodule DefinitionValidator.YamlMapValidator do
  @moduledoc """
  Validate pipeline definition.
  """

  @header "header-v1.0"
  @version_key "apiVersion"
  @body_key "spec"

  alias DefinitionValidator.YamlMapValidator.Server

  def start_link do
    Server.start_link()
  end

  def show_schemas do
    GenServer.call(Server, :show_schemas)
  end

  def validate_yaml(definition) when is_map(definition) do
    with {:ok, _header}     <- GenServer.call(Server, {:validate, @header, definition}),
         {:ok, api_version} <- get_version(definition, @version_key),
         body               <- Map.get(definition, @body_key),
         {:ok, _body}       <- GenServer.call(Server, {:validate, api_version, body})
    do
      {:ok, definition}
    end
  end
  def validate_yaml(definition), do: {:error, {:malformed, {:expected_map, definition}}}

  defp get_version(definition, version_key), do:
    definition |> Map.get(version_key) |> validate_version()

  defp validate_version(version) when is_binary(version), do: {:ok, version}
  defp validate_version(_), do:
    {:error, {:malformed, "Required property 'version' missing or not string"}}
end
