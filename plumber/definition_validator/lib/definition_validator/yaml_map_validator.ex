defmodule DefinitionValidator.YamlMapValidator do
  @moduledoc """
  Validate pipeline definition.
  """

  alias DefinitionValidator.YamlMapValidator.Server

  def start_link do
    Server.start_link()
  end

  def show_schemas do
    GenServer.call(Server, :show_schemas)
  end

  def validate_yaml(ppl_def) when is_map(ppl_def) do
    GenServer.call(Server, {:validate, ppl_def})
  end
  def validate_yaml(ppl_def), do: {:error, {:malformed, {:expected_map, ppl_def}}}

end
