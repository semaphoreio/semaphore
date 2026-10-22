defmodule Zebra.Workers.Scheduler.Trigger do
  @moduledoc """
  Coalesces scheduling requests per organization.

  Job.enqueue, Job.finish, Job.stop and Job.force_finish ask for a scheduling
  pass of the job's organization. Instead of one process per request, every
  organization has at most one pass in flight in this node:

    - A request for an idle organization starts a pass after `delay`
      milliseconds, which leaves time for the caller's transaction to commit.
    - A request that arrives while a pass is waiting to start, queued or
      running marks the organization dirty. When the pass ends, a dirty
      organization gets one more pass, again after `delay`. Every request is
      therefore followed by a pass that starts at least `delay` after it, and
      a burst of requests costs at most two passes.
    - A pass that loses the advisory lock (another node or the periodic tick
      holds it) is retried once, waiting for the lock to be released, instead
      of being dropped until the next tick. The wait is bounded by
      `lock_wait_timeout`.
    - At most `max_concurrency` passes run at once in this node, so a burst
      of requests across many organizations can't take every connection of
      the pool. Organizations over the limit wait in a FIFO queue.

  The periodic tick in Zebra.Workers.Scheduler stays the safety net for
  anything this node never heard about.
  """

  use GenServer
  require Logger

  @default_delay 100
  @default_max_concurrency 3
  @default_lock_wait_timeout 2_000

  defstruct [
    :run,
    :task_supervisor,
    :delay,
    :max_concurrency,
    :lock_wait_timeout,
    orgs: %{},
    tasks: %{},
    queue: :queue.new()
  ]

  ## API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @doc """
  Asks for a scheduling pass of the organization. Returns immediately.

  If the trigger is not running in this node, it falls back to a one-off
  process that runs the pass after the delay.
  """
  def request(org_id, server \\ __MODULE__) do
    if alive?(server) do
      GenServer.cast(server, {:request, org_id})
    else
      spawn(fn ->
        :timer.sleep(config(:async_delay, @default_delay))
        Zebra.Workers.Scheduler.lock_and_process(org_id)
      end)
    end

    :ok
  end

  defp alive?(server) when is_atom(server), do: Process.whereis(server) != nil
  defp alive?(server) when is_pid(server), do: Process.alive?(server)

  ## Callbacks

  @impl true
  def init(opts) do
    state = %__MODULE__{
      run: Keyword.get(opts, :run, &default_run/2),
      task_supervisor:
        Keyword.get(opts, :task_supervisor, Zebra.Workers.Scheduler.TaskSupervisor),
      delay: Keyword.get(opts, :delay, config(:async_delay, @default_delay)),
      max_concurrency:
        Keyword.get(
          opts,
          :max_concurrency,
          config(:async_max_concurrency, @default_max_concurrency)
        ),
      lock_wait_timeout:
        Keyword.get(
          opts,
          :lock_wait_timeout,
          config(:lock_wait_timeout, @default_lock_wait_timeout)
        )
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:request, org_id}, state) do
    case Map.fetch(state.orgs, org_id) do
      {:ok, org} ->
        Watchman.increment("scheduler.trigger.coalesced")
        {:noreply, put_org(state, org_id, %{org | dirty: true})}

      :error ->
        {:noreply, wait_then_start(state, org_id)}
    end
  end

  @impl true
  def handle_info({:ready, org_id}, state) do
    {:noreply, start_or_queue(state, org_id)}
  end

  def handle_info({ref, outcome}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, finished(state, ref, outcome)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    Logger.error("Scheduling pass crashed: #{inspect(reason)}")
    {:noreply, finished(state, ref, :crashed)}
  end

  def handle_info(_, state), do: {:noreply, state}

  @doc false
  def summary(server \\ __MODULE__), do: GenServer.call(server, :summary)

  @doc """
  Waits until no organization has a pending or running pass, or until the
  timeout. Returns :ok or :timeout. Used by tests to keep passes requested by
  one test from running in the next one.
  """
  def await_idle(server \\ __MODULE__, timeout_ms \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_await_idle(server, deadline)
  end

  defp do_await_idle(server, deadline) do
    cond do
      not alive?(server) or summary(server).orgs == %{} ->
        :ok

      System.monotonic_time(:millisecond) > deadline ->
        :timeout

      true ->
        :timer.sleep(10)
        do_await_idle(server, deadline)
    end
  end

  @impl true
  def handle_call(:summary, _from, state) do
    {:reply,
     %{
       orgs: state.orgs,
       running: map_size(state.tasks),
       queued: :queue.len(state.queue)
     }, state}
  end

  ## Internals

  defp wait_then_start(state, org_id) do
    Process.send_after(self(), {:ready, org_id}, state.delay)
    put_org(state, org_id, %{phase: :waiting, dirty: false})
  end

  defp start_or_queue(state, org_id) do
    if map_size(state.tasks) < state.max_concurrency do
      start(state, org_id, :try)
    else
      org = Map.fetch!(state.orgs, org_id)

      state
      |> put_org(org_id, %{org | phase: :queued})
      |> Map.update!(:queue, &:queue.in(org_id, &1))
    end
  end

  defp start(state, org_id, mode) do
    run = state.run
    timeout = state.lock_wait_timeout

    task =
      Task.Supervisor.async_nolink(state.task_supervisor, fn ->
        run.(org_id, {mode, timeout})
      end)

    org = Map.fetch!(state.orgs, org_id)

    state
    |> put_org(org_id, %{org | phase: :running})
    |> Map.update!(:tasks, &Map.put(&1, task.ref, {org_id, mode}))
  end

  defp finished(state, ref, outcome) do
    case Map.pop(state.tasks, ref) do
      {nil, _} ->
        state

      {{org_id, mode}, tasks} ->
        state = %{state | tasks: tasks}

        state =
          if outcome == :skipped and mode == :try do
            #
            # Someone else holds the lock and their pass may have read the
            # jobs before ours were committed. Run once more, after they are
            # done.
            #
            Watchman.increment("scheduler.trigger.lock_skipped")
            start(state, org_id, :wait)
          else
            if outcome == :lock_timeout do
              Watchman.increment("scheduler.trigger.lock_wait_timeout")
              Logger.info("[#{org_id}] Gave up waiting for the scheduling lock")
            end

            after_pass(state, org_id)
          end

        start_queued(state)
    end
  end

  defp after_pass(state, org_id) do
    org = Map.fetch!(state.orgs, org_id)

    if org.dirty do
      wait_then_start(state, org_id)
    else
      %{state | orgs: Map.delete(state.orgs, org_id)}
    end
  end

  defp start_queued(state) do
    if map_size(state.tasks) < state.max_concurrency do
      case :queue.out(state.queue) do
        {{:value, org_id}, queue} -> start_queued(start(%{state | queue: queue}, org_id, :try))
        {:empty, _} -> state
      end
    else
      state
    end
  end

  defp put_org(state, org_id, org), do: %{state | orgs: Map.put(state.orgs, org_id, org)}

  defp default_run(org_id, {mode, timeout}) do
    lock_mode = if mode == :wait, do: {:wait, timeout}, else: :try

    case Zebra.Workers.Scheduler.lock_and_process(org_id, lock_mode) do
      {:ok, {:lock_obtained, _}} -> :done
      {:ok, {:lock_skipped, _}} -> :skipped
      {:error, :lock_timeout} -> :lock_timeout
      other -> other
    end
  end

  defp config(key, default) do
    :zebra
    |> Application.get_env(Zebra.Workers.Scheduler, [])
    |> Keyword.get(key, default)
  end
end
