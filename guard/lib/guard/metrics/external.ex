defmodule Guard.Metrics.External do
  @moduledoc """
  Helper module for sending external metrics in OnPrem environments.
  """

  @doc """
  Increments a metric in the external metrics backend if running in OnPrem mode.
  """
  def increment(metric_name, tags \\ []) do
    if Guard.on_prem?() do
      Watchman.increment(external: {metric_name, tags})
    end
  end
end
