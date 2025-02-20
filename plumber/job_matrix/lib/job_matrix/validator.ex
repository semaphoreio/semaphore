defmodule JobMatrix.Validator do
  @moduledoc """
  Validates Matrix and transforms it into EnvVars List.

  Each element(Axis) in Matrix must be a Map with 'env_var' and 'value' fields or
  a Map with 'software' and 'versions' fields.
  """

  @doc ~S"""
  ##Example

      iex> JobMatrix.Validator.validate([
      ...> %{"env_var" => "ERLANG", "values" => ["18", "19"]},
      ...> %{"software" => "PYTHON", "versions" => ["2.7", "3.4"]}])
      {:ok, "Matrix is valid."}

  """
  def validate(nil), do: {:ok, nil}
  def validate(matrix) do
    validate_matrix(matrix)
    check_for_duplicate_names(matrix)
    {:ok, "Matrix is valid."}
  catch
    error -> {:error, error}
  end

  defp validate_matrix(matrix) do
    if not is_list(matrix) or Enum.empty?(matrix),
      do: throw {:malformed, "'matrix' must be non-empty List."}

    Enum.each(matrix, fn(axis) -> validate_axis(axis) end)
  end

  defp validate_axis(%{"env_var" => name, "values" => values})
  when is_binary(name) and is_list(values) do
    if Enum.empty?(values),
      do: throw {:malformed, "List 'values' in job matrix must not be empty."}
  end
  defp validate_axis(%{"software" => name, "versions" => values})
  when is_binary(name) and is_list(values) do
    if Enum.empty?(values),
      do: throw {:malformed, "List 'versions' in job matrix must not be empty."}
  end
  defp validate_axis(axis) do
    throw {:malformed, "Job matrix: #{inspect axis} missing required field(s)."}
  end

  defp check_for_duplicate_names(matrix),
    do: matrix |> Enum.map(&get_name(&1)) |> duplicate_check()

  defp duplicate_check([head | tail]), do: contains(head in tail, head, tail)
  defp duplicate_check(_), do: {:ok, "There are no duplicates."}

  defp contains(true, head, _),
    do: throw {:malformed, "Duplicate name: '#{head}' in Matrix."}
  defp contains(false, _head, tail), do: duplicate_check(tail)

  defp get_name(%{"env_var" => name}), do: name
  defp get_name(%{"software" => name}), do: name
end
