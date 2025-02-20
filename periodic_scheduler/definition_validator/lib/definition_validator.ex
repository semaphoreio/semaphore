defmodule DefinitionValidator do
  @moduledoc """
  Validates yaml string.
  Returns definition map if input is valid.
  """

  alias DefinitionValidator.{YamlStringParser, YamlMapValidator}

  def validate_yaml_string(yaml_string) do
    yaml_string
    |> do_validate_yaml_string()
    |> pretty_print()
  end

  defp do_validate_yaml_string(yaml_string) do
    with  {:ok, definition}     <- YamlStringParser.parse(yaml_string),
          {:ok, ^definition}    <- YamlMapValidator.validate_yaml(definition),
    do: {:ok, definition}
  end


  defp pretty_print({:error, {:malformed, errors}}) when is_list(errors) do
    errors
    |> Enum.map(&reformat_error/1)
    |> nest()
  end

  defp pretty_print(response), do: response

  defp reformat_error({:data_invalid, spec, err, specified_value, position}),
    do: {:data_invalid, position, err, specified_value, spec}

  defp reformat_error(error), do: error

  defp nest(prettyfied), do: {:error, {:malformed, prettyfied}}
end
