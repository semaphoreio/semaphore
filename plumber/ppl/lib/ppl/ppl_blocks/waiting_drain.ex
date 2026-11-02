defmodule Ppl.PplBlocks.WaitingDrain do
  @moduledoc """
  Event-driven scheduling of waiting pipeline blocks, one pipeline at a time.

  Each `trigger/1` call enqueues a pipeline whose waiting blocks may have become
  ready (pipeline started running, one of its blocks finished, it was
  terminated...). Queued pipelines are drained by at most `max_tasks` tasks in
  parallel, and each task schedules ready blocks of its pipeline until none is
  left (see `Ppl.PplBlocks.STMHandler.WaitingState.drain_pipeline/1`).

  - A pipeline that is already queued is not queued twice.
  - A pipeline that is triggered while it is being drained is queued again once
    the current drain finishes, so readiness changes that happen during a drain
    are not missed.
  - With `max_tasks` set to 0 draining is disabled and each trigger only wakes up
    periodic scheduling of WaitingState, as it was done before draining existed.
  """

  use GenServer

  alias LogTee, as: LT
  alias Ppl.PplBlocks.STMHandler.WaitingState

  @task_supervisor Ppl.PplBlocks.WaitingDrainTaskSupervisor
  @default_max_tasks 1
  @metric_name "Ppl.ppl_blk.waiting_drain"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def task_supervisor, do: @task_supervisor

  @doc """
  Request draining of all ready waiting blocks of given pipeline.
  """
  def trigger(ppl_id) when is_binary(ppl_id), do: GenServer.cast(__MODULE__, {:trigger, ppl_id})
  def trigger(_ppl_id), do: :ok

  def init(opts) do
    max_tasks = Keyword.get(opts, :max_tasks) || max_tasks_from_config()

    {:ok,
     %{
       queue: :queue.new(),
       queued: MapSet.new(),
       running: %{},
       rerun: MapSet.new(),
       max_tasks: max_tasks
     }}
  end

  def handle_cast({:trigger, _ppl_id}, state = %{max_tasks: 0}) do
    WaitingState.execute_now()
    {:noreply, state}
  end

  def handle_cast({:trigger, ppl_id}, state) do
    state =
      cond do
        draining?(state, ppl_id) -> %{state | rerun: MapSet.put(state.rerun, ppl_id)}
        MapSet.member?(state.queued, ppl_id) -> state
        true -> enqueue(state, ppl_id)
      end

    {:noreply, state |> start_tasks() |> report_metrics()}
  end

  # Task finished
  def handle_info({ref, _result}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, state |> task_done(ref) |> start_tasks() |> report_metrics()}
  end

  # Task crashed
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    state.running |> Map.get(ref) |> LT.warn("WaitingDrain task crashed: #{inspect(reason)}")
    {:noreply, state |> task_done(ref) |> start_tasks() |> report_metrics()}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp draining?(state, ppl_id), do: state.running |> Map.values() |> Enum.member?(ppl_id)

  defp enqueue(state, ppl_id) do
    %{state | queue: :queue.in(ppl_id, state.queue), queued: MapSet.put(state.queued, ppl_id)}
  end

  defp task_done(state, ref) do
    {ppl_id, running} = Map.pop(state.running, ref)
    state = %{state | running: running}

    if ppl_id != nil and MapSet.member?(state.rerun, ppl_id) do
      %{state | rerun: MapSet.delete(state.rerun, ppl_id)} |> enqueue(ppl_id)
    else
      state
    end
  end

  defp start_tasks(state = %{running: running, max_tasks: max}) when map_size(running) >= max,
    do: state

  defp start_tasks(state) do
    case :queue.out(state.queue) do
      {:empty, _queue} ->
        state

      {{:value, ppl_id}, queue} ->
        case start_task(ppl_id) do
          {:ok, ref} ->
            %{
              state
              | queue: queue,
                queued: MapSet.delete(state.queued, ppl_id),
                running: Map.put(state.running, ref, ppl_id)
            }
            |> start_tasks()

          # Pipeline stays first in the queue, starting is retried on next event
          :error ->
            state
        end
    end
  end

  defp start_task(ppl_id) do
    %{ref: ref} =
      Task.Supervisor.async_nolink(@task_supervisor, WaitingState, :drain_pipeline, [ppl_id])

    {:ok, ref}
  catch
    :exit, reason ->
      ppl_id |> LT.warn("WaitingDrain could not start task: #{inspect(reason)}")
      :error
  end

  defp report_metrics(state) do
    Watchman.submit({@metric_name, ["queued"]}, :queue.len(state.queue))
    Watchman.submit({@metric_name, ["running"]}, map_size(state.running))
    state
  end

  defp max_tasks_from_config do
    case Application.get_env(:ppl, :ppl_blk_waiting_drain_max_tasks) do
      value when is_integer(value) and value >= 0 -> value
      _ -> @default_max_tasks
    end
  end
end
