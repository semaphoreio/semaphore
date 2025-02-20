defmodule Front.DatePicker do
  @default_range {-6, 0}
  @ranges [
    {{-1, 0}, "Last 2 days"},
    {{-6, 0}, "Last 7 days"},
    {{-29, 0}, "Last 30 days"},
    {{-1, -1}, "Yesterday"}
  ]

  def construct(from, to) do
    range = parse(from, to)

    %{
      label: label(range),
      range: range,
      options: @ranges |> Enum.map(fn {range, label} -> {range(range), label} end),
      custom: custom?(range)
    }
  end

  defp custom?(range) do
    case @ranges |> Enum.find(fn {r, _} -> range(r) == range end) do
      nil -> true
      _ -> false
    end
  end

  defp label(range) do
    l =
      "#{range.first |> Timex.format!("{0D} {Mshort} {YYYY}")} - #{range.last |> Timex.format!("{0D} {Mshort} {YYYY}")}"

    @ranges
    |> Enum.find_value(l, fn {r, label} -> if range(r) == range, do: label end)
  end

  defp parse(from, to) do
    with {:ok, from} <- Date.from_iso8601(from),
         {:ok, to} <- Date.from_iso8601(to) do
      Date.range(from, to)
    else
      {:error, _} -> range(@default_range)
    end
  end

  def range({from, to}) do
    Date.range(date(from), date(to))
  end

  defp date(0), do: Timex.today()
  defp date(shift), do: Timex.shift(Timex.today(), days: shift)
end
