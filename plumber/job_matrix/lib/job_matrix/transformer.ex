defmodule JobMatrix.Transformer do
  @moduledoc """
  Transforms Matrix into EnvVars List.
  """

  alias JobMatrix.Cartesian

  @doc ~S"""
  ##Example

      iex> JobMatrix.Transformer.to_env_vars_list(nil)
      {:ok, []}

      iex> JobMatrix.Transformer.to_env_vars_list([
      ...> %{"env_var" => "ERLANG", "values" => ["18", "19"]},
      ...> %{"software" => "PYTHON", "versions" => ["2.7", "3.4"]}])
      {:ok,
            [[%{name: "ERLANG", value: "18"}, %{name: "PYTHON", value: "2.7"}],
             [%{name: "ERLANG", value: "18"}, %{name: "PYTHON", value: "3.4"}],
             [%{name: "ERLANG", value: "19"}, %{name: "PYTHON", value: "2.7"}],
             [%{name: "ERLANG", value: "19"}, %{name: "PYTHON", value: "3.4"}]]}

  """
  def to_env_vars_list(nil), do: {:ok, []}
  def to_env_vars_list(matrix), do:
    matrix |> Enum.reduce([], &calculate_product(&1, &2)) |> to_ok_tuple()

  defp calculate_product(%{"env_var" => name, "values" => values}, acc), do:
    cartesian_product(name, values, acc)
  defp calculate_product(%{"software" => name, "versions" => values}, acc), do:
    cartesian_product(name, values, acc)

  defp cartesian_product(name, values, acc) do
    with {:ok, product} <- Cartesian.product(name, values, acc),
    do: product
  end

  defp to_ok_tuple(state) do {:ok, state} end
end
