defmodule HooksProcessor.Metrics do
  @moduledoc """
  Sends hook related metrics to statsd every
  N minutes. The metrics that we send are:

    - hooks.processing.stuck.count
  """

  alias HooksProcessor.Hooks.Model.HooksQueries
  alias LogTee, as: LT

  # in milis
  @naptime 60 * 1000
  @treshold 15 * 1000

  # in seconds
  @deadline 24 * 60 * 60

  @provider "github"

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    }
  end

  def start_link do
    pid = spawn_link(fn -> loop() end)

    {:ok, pid}
  end

  def loop do
    :timer.sleep(@naptime)

    LT.info("", "Started measuring stuck hooks")

    measure()
    loop()
  end

  def measure do
    {:ok, hooks} = load_hooks()
    total_stuck_hook_count = length(hooks)

    metric_name = "hooks.processing.stuck.count"
    external_metric_name = "IncomingHooks.processing"

    Watchman.submit(
      [internal: {metric_name, ["total"]}, external: {external_metric_name, [state: "stuck"]}],
      total_stuck_hook_count
    )
  rescue
    e ->
      LT.warn(e, "Failed to count stuck hooks")
  end

  defp load_hooks do
    HooksQueries.hooks_stuck_in_processing(@provider, @treshold, @deadline)
  end
end
