defmodule FrontWeb.SharedView do
  use FrontWeb, :view

  def total_seconds(start, nil), do: total_seconds(start, 0)
  def total_seconds(nil, finish), do: total_seconds(0, finish)

  def total_seconds(start, finish) do
    cond do
      finish == 0 && start != 0 -> :os.system_time(:seconds) - start
      finish != 0 && start != 0 -> finish - start
      true -> 0
    end
  end

  def total_time(start, finish) do
    total_seconds(start, finish) |> Front.DurationFormatter.format()
  end

  def timer_color(job) do
    cond do
      job.failed? -> "red"
      job.running? -> "indigo"
      job.done? -> "green"
      true -> "gray"
    end
  end
end
