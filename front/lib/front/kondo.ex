defmodule Front.Kondo do
  @doc """
  `categorize_by_name` supports project sorting on projects page:
  - project_path(conn, :index)

  Example output:
    [
      {"0-9", [%{name: "202"}, %{name: "404a", desc: "bb"}]},
      {"T", [%{name: "Test2"}, %{name: "Test7", desc: "aa"}]}
    ]
  """
  def categorize_by_name(list) do
    list
    |> Enum.reduce(%{}, fn x, categorized ->
      Map.update(categorized, get_category(x.name), [x], fn a -> a ++ [x] end)
    end)
    |> Enum.sort()
    |> Enum.map(&sort_category_by_name(&1))
  end

  defp sort_category_by_name({category_name, category_list}) do
    {
      category_name,
      Enum.sort_by(category_list, fn a -> a.name end)
    }
  end

  defp get_category(string) do
    string
    |> String.first()
    |> then(fn letter -> if is_integer?(letter), do: "0-9", else: letter end)
    |> String.upcase()
  end

  defp is_integer?(string) do
    case Integer.parse(string) do
      {_num, ""} -> true
      _ -> false
    end
  end
end
