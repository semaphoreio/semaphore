defmodule RepositoryHub.WebhookEncryptor.WorkerConsumer do
  @moduledoc """
  Consumes token events, queues them and forwards to the encryption workers.

  Only one worker per access token is running. If more events that use the same token
  are consumed, they are queued internally (up to the max queue size). This allows
  for a bit of parallelism, but keeps the back-pressure on the producer.

  Workers can be restarted if they fail, but only up to a certain number of attempts.
  Retry interval is either received directly from API or set to a default value.
  """

  use GenStage
  require Logger

  @max_demand 10
  @min_demand 5
  @max_attempts 2
  @max_queue_size 25
  @wait_time 10

  @type event :: %{token: String.t(), project_id: String.t()}

  @type worker :: %{
          events: :queue.t(),
          token: String.t(),
          attempts: non_neg_integer(),
          ref: reference(),
          timer_ref: reference()
        }

  @type state :: %{
          workers: %{String.t() => worker},
          min_demand: non_neg_integer() | nil,
          max_demand: non_neg_integer() | nil,
          producer: reference() | nil
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) do
    GenStage.start_link(__MODULE__, args, name: __MODULE__)
  end

  @spec ask_for_demand() :: :ok
  def ask_for_demand do
    Process.send(__MODULE__, :ask_for_demand, [])
  end

  # GenStage callbacks

  @impl true
  def init(_args) do
    alias RepositoryHub.WebhookEncryptor.Worker

    {:consumer,
     %{
       worker_module: Worker,
       workers: %{},
       min_demand: nil,
       max_demand: nil,
       producer: nil
     },
     subscribe_to: [
       {
         RepositoryHub.WebhookEncryptor.TokenEnricher,
         max_demand: @max_demand, min_demand: @min_demand
       }
     ]}
  end

  @impl true
  def handle_subscribe(:producer, opts, from, state) do
    Process.send(self(), :ask_for_demand, [])

    {:manual,
     %{
       state
       | max_demand: opts[:max_demand] || @max_demand,
         min_demand: opts[:min_demand] || @min_demand,
         producer: from
     }}
  end

  @impl true
  def handle_cancel(_reason, _from, state) do
    {:noreply, [],
     %{
       state
       | min_demand: nil,
         max_demand: nil,
         producer: nil
     }}
  end

  @impl true
  def handle_events(events, _from, state) do
    new_state =
      events
      |> Enum.reduce(state, &handle_event/2)
      |> maybe_ask_for_demand()

    {:noreply, [], new_state}
  end

  @impl true
  def handle_info(:ask_for_demand, state) do
    Logger.debug(log("🚀 Explicitly asking for demand..."))
    {:noreply, [], maybe_ask_for_demand(state)}
  end

  def handle_info({:retry, token}, state) do
    new_state =
      state.workers
      |> find_worker_by_token(token)
      |> start_worker(state)
      |> maybe_ask_for_demand()

    {:noreply, [], new_state}
  end

  def handle_info({ref, {:ok, _event}}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    message = {:info, "✅ Processing repository finished"}
    {:noreply, [], dequeue_and_start(message, ref, state)}
  end

  def handle_info({ref, {:retry, interval}}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, [], schedule_retry(interval, ref, state)}
  end

  def handle_info({ref, {:abort, reason}}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    message = {:warn, "🖐🏻 Processing repository aborted: #{inspect(reason)}"}
    {:noreply, [], dequeue_and_start(message, ref, state)}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {:noreply, [], schedule_retry(@wait_time, ref, state)}
  end

  # event handling

  @spec handle_event(event(), state()) :: state()
  def handle_event(event, state) do
    case find_worker_by_token(state.workers, event.token) do
      nil ->
        event
        |> new_worker_from_event()
        |> start_worker(state)

      worker ->
        new_worker = %{worker | events: :queue.in(event, worker.events)}
        %{state | workers: Map.put(state.workers, worker.token, new_worker)}
    end
  end

  @spec dequeue_and_start({atom(), String.t()}, reference(), state()) :: state()
  def dequeue_and_start({level, message}, ref, state) do
    case find_worker_by_ref(state.workers, ref) do
      nil ->
        Logger.warning(log("🚫 Worker #{inspect(ref)} not found"))
        maybe_ask_for_demand(state)

      worker ->
        worker
        |> dequeue_worker(level, message)
        |> start_worker(state)
        |> maybe_ask_for_demand()
    end
  end

  @spec schedule_retry(non_neg_integer(), reference(), state()) :: state()
  def schedule_retry(interval, ref, state) do
    case find_worker_by_ref(state.workers, ref) do
      nil ->
        Logger.warning(log("🚫 Worker #{inspect(ref)} not found"))
        maybe_ask_for_demand(state)

      worker ->
        worker
        |> schedule_worker_retry(interval)
        |> add_worker_to_state(state)
    end
  end

  @spec maybe_ask_for_demand(map) :: map
  def maybe_ask_for_demand(state) do
    pending = map_size(state.workers)

    max_queue_size =
      state.workers
      |> Stream.map(&elem(&1, 1))
      |> Stream.map(& &1.events)
      |> Stream.map(&:queue.len/1)
      |> Enum.max(fn -> 0 end)

    if pending < state.min_demand && max_queue_size < @max_queue_size do
      Logger.debug(log("🚀 Asking for demand (pending: #{pending}, max_queue_size: #{max_queue_size})"))
      GenStage.ask(state.producer, state.max_demand - pending)
    else
      Logger.debug(log("🚫 No demand needed (pending: #{pending}, max_queue_size: #{max_queue_size})"))
    end

    state
  end

  defp dequeue_worker(worker, level, message) do
    if worker.timer_ref, do: Process.cancel_timer(worker.timer_ref)
    {maybe_event, events} = :queue.out(worker.events)

    case maybe_event do
      {:value, event} -> Logger.log(level, log(event, message))
      :empty -> Logger.debug(log("🚫 No events in worker queue"))
    end

    %{worker | events: events, attempts: 0, ref: nil, timer_ref: nil}
  end

  defp start_worker(%{attempts: attempts} = worker, state)
       when attempts >= @max_attempts do
    message = "⛔️ Max attempts reached, moving on"

    worker
    |> dequeue_worker(:warn, message)
    |> start_worker(state)
  end

  defp start_worker(%{attempts: attempts} = worker, state) when attempts < @max_attempts do
    if worker.timer_ref,
      do: Process.cancel_timer(worker.timer_ref)

    case :queue.peek(worker.events) do
      {:value, event} ->
        Logger.info(log(event, "⏳ Starting processing repository"))

        task = state.worker_module.perform_async(event)
        updates = %{ref: task.ref, timer_ref: nil, attempts: attempts + 1}

        new_worker = Map.merge(worker, updates)
        %{state | workers: Map.put(state.workers, worker.token, new_worker)}

      :empty ->
        Logger.info(log("⌛️ Freeing worker"))
        %{state | workers: Map.delete(state.workers, worker.token)}
    end
  end

  defp schedule_worker_retry(%{token: token} = worker, interval) do
    if worker.timer_ref, do: Process.cancel_timer(worker.timer_ref)
    %{worker | timer_ref: Process.send_after(self(), {:retry, token}, interval * 1_000)}
  end

  defp add_worker_to_state(worker, state) do
    %{state | workers: Map.put(state.workers, worker.token, worker)}
  end

  defp new_worker_from_event(event) do
    %{events: :queue.in(event, :queue.new()), token: event.token, attempts: 0, ref: nil, timer_ref: nil}
  end

  defp find_worker_by_token(workers, token),
    do: Map.get(workers, token)

  defp find_worker_by_ref(workers, ref) do
    Enum.find_value(workers, fn
      {_token, %{ref: ^ref} = worker} -> worker
      {_token, _worker} -> false
    end)
  end

  @log_prefix "[WebhookEncryptor][WorkerConsumer]"
  defp log(event, message), do: "#{@log_prefix} {#{event.project_id}} #{message}"
  defp log(message), do: "#{@log_prefix} #{message}"
end
