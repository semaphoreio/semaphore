defmodule GithubNotifier.StatusGuard.HealthCheck do
  @moduledoc """
  Periodically verifies the guard's Redis is safe to trust.

  `maxmemory-policy` other than `noeviction` can evict guard keys under memory
  pressure, turning lost protection into wrong decisions — the guard is pinned
  to fail-open (and a metric alarms) until the policy is fixed. AOF disabled
  only narrows the restart-loss window, so it just warns. Managed Redis often
  disables CONFIG; that logs once and the guard stays trusted.
  """

  use GenServer

  alias GithubNotifier.StatusGuard

  require Logger

  @interval :timer.seconds(60)
  @first_check_after :timer.seconds(5)

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    Process.send_after(self(), :check, @first_check_after)
    {:ok, %{config_warned: false, aof_warned: false}}
  end

  @impl true
  def handle_info(:check, state) do
    state = state |> check_eviction_policy() |> check_persistence()
    Process.send_after(self(), :check, @interval)
    {:noreply, state}
  end

  defp check_eviction_policy(state) do
    case redis_command(["CONFIG", "GET", "maxmemory-policy"]) do
      {:ok, ["maxmemory-policy", "noeviction"]} ->
        StatusGuard.force_fail_open(false)
        state

      {:ok, ["maxmemory-policy", policy]} ->
        StatusGuard.force_fail_open(true)
        Watchman.increment("status_guard.misconfigured")

        Logger.error(
          "[StatusGuard] redis maxmemory-policy is #{policy}, needs noeviction — " <>
            "guard disabled (fail-open) until fixed"
        )

        state

      {:error, reason} ->
        unless state.config_warned do
          Logger.warning("[StatusGuard] cannot verify redis eviction policy: #{inspect(reason)}")
        end

        %{state | config_warned: true}
    end
  end

  defp check_persistence(state) do
    with false <- state.aof_warned,
         {:ok, info} when is_binary(info) <- redis_command(["INFO", "persistence"]),
         true <- String.contains?(info, "aof_enabled:0") do
      Logger.warning("[StatusGuard] redis AOF is disabled — guard state can be lost on restart")
      %{state | aof_warned: true}
    else
      _ -> state
    end
  end

  defp redis_command(command) do
    Redix.command(StatusGuard.conn_name(0), command, timeout: 1_000)
  catch
    :exit, reason -> {:error, {:exit, reason}}
  end
end
