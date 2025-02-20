defmodule Zebra.Time do
  def datetime_diff_in_ms(t1, t2) do
    if t1 == nil or t2 == nil do
      {:error, "Can't calculate diff"}
    else
      {:ok, datetime_to_ms(t1) - datetime_to_ms(t2)}
    end
  end

  def datetime_to_ms(t) do
    DateTime.to_unix(t, :millisecond)
  end
end
