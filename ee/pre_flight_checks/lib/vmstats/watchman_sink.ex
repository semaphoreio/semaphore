defmodule VMStats.WatchmanSink do
  @moduledoc """
  vmstats sink for watchman
  """

  def collect(:gauge, key, value),
    do: Watchman.submit(key, value, :gauge)

  def collect(:counter, key, value),
    do: Watchman.submit(key, value, :count)

  def collect(:timing, key, value),
    do: Watchman.submit(key, value, :timing)
end
