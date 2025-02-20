defmodule Front.DateRangeGenerator do
  @ranges [
    {0, :period, 14},
    {1, :period, 30},
    {2, :period, 60},
    {3, :period, 90},
    {4, :month, 0},
    {5, :month, 1},
    {6, :month, 2},
    {7, :month, 3}
  ]

  def construct do
    @ranges
    |> Enum.map(&get_datetime_range_past/1)
  end

  defp get_datetime_range_past({index, :period, n}) do
    today = Date.utc_today()
    from = Date.add(today, -n)

    %{label: "#{n} days", from: from, to: today, index: index, type: :period, days: n}
  end

  defp get_datetime_range_past({index, :month, n}) do
    today = Date.utc_today()
    from = today |> Timex.shift(months: -n) |> Date.beginning_of_month()

    to = from |> Date.end_of_month()

    label = if n == 0, do: "Current month", else: Timex.format!(from, "{Mshort} {YYYY}")

    # +1 because we want to include the last day
    days = if n > 0, do: Date.diff(to, from) + 1, else: Date.diff(today, from)
    %{label: label, from: from, to: to, index: index, type: :month, days: days}
  end
end
