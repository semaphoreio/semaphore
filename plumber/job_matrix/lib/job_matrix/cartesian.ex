defmodule JobMatrix.Cartesian do
  @moduledoc """
  Calculates Cartesian Product of two Lists
  """

  @doc ~S"""
  ##Example

      iex> JobMatrix.Cartesian.product(
      ...> "ELIXIR", ["1.3", "1.4"], [])
      {:ok,
            [[%{name: "ELIXIR", value: "1.3"}],
             [%{name: "ELIXIR", value: "1.4"}]]}

      iex> JobMatrix.Cartesian.product(
      ...> "ERLANG", ["18", "19"],
      ...> [[%{name: "ELIXIR", value: "1.3"}], [%{name: "ELIXIR", value: "1.4"}]])
      {:ok,
            [[%{name: "ELIXIR", value: "1.3"}, %{name: "ERLANG", value: "18"}],
             [%{name: "ELIXIR", value: "1.3"}, %{name: "ERLANG", value: "19"}],
             [%{name: "ELIXIR", value: "1.4"}, %{name: "ERLANG", value: "18"}],
             [%{name: "ELIXIR", value: "1.4"}, %{name: "ERLANG", value: "19"}]]}
  """
  def product(name, _, _) when not is_binary(name),
    do: {:error, {:malformed, "'name' parameter must be of type String."}}

  def product(_, list, _) when not is_list(list) or list == [],
    do: {:error, {:malformed, "'list' parameter must be non-empty List."}}

  def product(_, _, acc) when not is_list(acc),
    do: {:error, {:malformed, "'acc' parameter must be of type List."}}

  def product(name, list, acc), do: {:ok, product_(name, list, acc)}

  def product_(name, list, []), do: for e <- list, do: [%{name: name, value: e}]

  def product_(name, list, acc) do
    for acc_e <- acc, e <- list, do: [acc_e, %{name: name, value: e}]
    |> List.flatten
  end
end
