defmodule Looper.CommonQuery do
  @moduledoc """
  Used by both Beholder and STM
  """

  import Ecto.Query

  #
  # def where_event_older_than_sec(q, seconds), do:
  #   q |> where([p], p.updated_at < datetime_add(^now_naive(), ^(-seconds), "second"))
  #
  # Note: We switched from using Ecto's datetime_add to a SQL fragment with NOW()
  # because datetime_add was not handling microseconds accurately.
  # Using raw SQL ensures that we get precise date arithmetic for our query.
  #
  def where_event_older_than_sec(q, seconds), do:
    q |> where([p], fragment("? < NOW() + (?::numeric * INTERVAL '1 SECOND')", p.updated_at, ^(-seconds)))

  def now_naive, do: DateTime.utc_now |> DateTime.to_naive
end
