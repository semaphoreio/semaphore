defmodule DefinitionValidator.PartialRerunValidator do
  @moduledoc """
  Validates the `partial_rerun` property of a pipeline definition.

  The property is read at rebuild time and anything other than "block" is
  treated as "jobs", so a typo would silently pick the wrong granularity.
  Reject unknown values while the user can still see the error.
  """

  @valid_values ~w(jobs block)

  def validate_yaml(definition) when is_map(definition) do
    with {:ok, definition} <- validate_pipeline_level(definition),
         do: validate_blocks(definition)
  end

  def validate_yaml(definition), do: {:ok, definition}

  defp validate_pipeline_level(definition) do
    case Map.fetch(definition, "partial_rerun") do
      {:ok, value} -> valid?(value, definition, "pipeline")
      :error -> {:ok, definition}
    end
  end

  defp validate_blocks(definition) do
    definition
    |> Map.get("blocks", [])
    |> Enum.reduce_while({:ok, definition}, fn block, acc ->
      case Map.fetch(block, "partial_rerun") do
        {:ok, value} ->
          case valid?(value, definition, block_name(block)) do
            {:ok, _} -> {:cont, acc}
            error -> {:halt, error}
          end

        :error ->
          {:cont, acc}
      end
    end)
  end

  defp valid?(value, definition, _where) when value in @valid_values, do: {:ok, definition}

  defp valid?(value, _definition, where),
    do: {:error, {:malformed, error_msg(value, where)}}

  defp block_name(block) do
    case Map.get(block, "name") do
      name when is_binary(name) and name != "" -> "block '#{name}'"
      _ -> "block"
    end
  end

  defp error_msg(value, where) do
    """
    Value '#{inspect(value)}' of 'partial_rerun' property on #{where} level is not valid.
    Valid values are: #{Enum.join(@valid_values, ", ")}.
    """
  end
end
