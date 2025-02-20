defmodule Ppl.VmstatsWatchmanSink do
  @moduledoc """
  Vmstats sink for watchman.
  """

  def collect(:gauge, key, value),    do: Watchman.submit(key, value, :gauge)

  def collect(:counter, key, value),  do: Watchman.submit(key, value, :count)

  def collect(:timing, key, value),   do: Watchman.submit(key, value, :timing)
end
