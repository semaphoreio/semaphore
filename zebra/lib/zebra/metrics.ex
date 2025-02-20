defmodule Zebra.Metrics do
  def submit_datetime_diff(name, t1, t2) do
    case Zebra.Time.datetime_diff_in_ms(t1, t2) do
      {:ok, duration} ->
        Watchman.submit(name, duration, :timing)

      _ ->
        # do nothing if the diff can't be calculated
        nil
    end
  end
end
