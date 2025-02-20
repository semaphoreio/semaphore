defmodule DefinitionValidator.YamlStringParser do
  @moduledoc """
  Yaml parser that returns tuples only (no exceptions).
  """

  @doc ~S"""
      iex> alias DefinitionValidator.YamlStringParser
      iex> YamlStringParser.parse("version: v1.0\nbuild: %{}")
      {:ok, %{"build" => "%{}", "version" => "v1.0"}}
  """
  def parse(yaml_string) do
    {:ok, YamlElixir.read_from_string(yaml_string)}
  rescue error ->
    {:error, {:malformed, {error, yaml_string}}}
  catch a, b ->
    {:error, {:malformed, {{a, b}, yaml_string}}}
  end

end
