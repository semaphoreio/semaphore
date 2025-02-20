defmodule Support.Time do
  def ago(minutes: m) do
    :erlang.universaltime()
    |> :calendar.datetime_to_gregorian_seconds()
    |> Kernel.-(m * 60)
    |> :calendar.gregorian_seconds_to_datetime()
    |> NaiveDateTime.from_erl!()
  end
end
