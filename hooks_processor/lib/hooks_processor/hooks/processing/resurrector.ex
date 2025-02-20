defmodule HooksProcessor.Hooks.Processing.Resurrector do
  @moduledoc """
  It periodically scans DB for all hooks that are in processing state for longer
  than configured @threshold and starts a new worker process for each of them.
  If hooks are stuck for longer than @deadline, resurrecotr will ignore them and
  finisher will eventually transition them to failed state.
  """

  use GenServer

  alias HooksProcessor.Hooks.Processing.WorkersSupervisor
  alias HooksProcessor.Hooks.Model.HooksQueries
  alias Util.ToTuple
  alias LogTee, as: LT

  # 24h in seconds
  @deadline 86_400
  @threshold 15_000
  @resurect_cooltime 5_000

  def start_link(_params) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(_params) do
    provider = Application.get_env(:hooks_processor, :webhook_provider)

    Process.send_after(self(), :resurrect, @resurect_cooltime)

    {:ok, %{provider: provider}}
  end

  def handle_info(:resurrect, state = %{provider: provider}) do
    "#{@threshold / 1000} seconds"
    |> LT.info("Resurrector - resurecting workers for all #{provider} hooks in proceesing longer than")

    with {:ok, hooks} <- HooksQueries.hooks_stuck_in_processing(provider, @threshold, @deadline),
         {:ok, workers} <- resurrect_workers(hooks) do
      "#{@resurect_cooltime / 1000} seconds"
      |> LT.info("Resurrector - resurected #{length(workers)} workers, cooling time befor next iteration")

      Process.send_after(self(), :resurrect, @resurect_cooltime)

      {:noreply, state}
    else
      error ->
        error |> LT.warn("Resurector - error while resurecting workers")

        {:stop, :restart, state}
    end
  end

  defp resurrect_workers(hooks) do
    hooks
    |> Enum.reduce([], fn hook, acc ->
      case WorkersSupervisor.start_worker_for_webhook(hook.id) do
        {:ok, pid} ->
          acc ++ [pid]

        error ->
          error |> LT.warn("Resurrector - starting worker for hook #{hook.id} failed")
      end
    end)
    |> ToTuple.ok()
  end
end
