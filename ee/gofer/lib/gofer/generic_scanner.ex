defmodule Gofer.GenericScanner do
  @moduledoc """
  Generic scanner loading processable entities

  Generic scanner loads processable entities in batches, and then starts
  workers for each of them. It is necessary at the application startup,
  when some entities might be left in the unfinished state and need further
  action to reach the terminal state defined by their FSM.

  Required arguments for the start_link/2 function (provided as a keyword):
  - :scanner_fun - MFA-styled function of arity 3 accepting following arguments:
    - startup time - as NaiveDateTime struct
    - batch number - as an integer value
    - bacth_size - as an integer value
  - :start_worker_fun - MFA-styled function of arity 1 accepting entity as an argument
    (as returned by the :scanner_fun)

  Generic scanner is restarted
  """

  require Logger
  @batch_size 100

  defmacro __using__(_opts) do
    quote do
      use GenServer, restart: :transient

      defdelegate init(args), to: Gofer.GenericScanner
      defdelegate handle_info(msg, state), to: Gofer.GenericScanner
      defdelegate scan(batch_no, total \\ 0, state), to: Gofer.GenericScanner
    end
  end

  def start_link(module, args) do
    GenServer.start_link(module, args, name: module)
  end

  # GenServer callbacks

  def init(args) do
    state =
      args
      |> check_function(:scanner_fun, 3)
      |> check_function(:start_worker_fun, 1)
      |> Keyword.put_new(:startup_time, NaiveDateTime.utc_now())
      |> Keyword.put_new(:batch_size, @batch_size)
      |> Map.new()

    Kernel.send(self(), :scan)
    {:ok, state}
  end

  def handle_info(:scan, state) do
    case scan(0, state) do
      {:ok, _num_processed} -> {:stop, :normal, state}
      {:error, _reason} -> {:stop, :restart, state}
    end
  end

  def scan(batch_no, total \\ 0, state) do
    entities = state.scanner_fun.(state.startup_time, batch_no, state.batch_size)

    case start_workers(entities, state.start_worker_fun, total) do
      {:ok, new_total} when new_total > total ->
        scan(batch_no + 1, new_total, state)

      {:ok, ^total} ->
        {:ok, total}

      {:error, reason} ->
        log_error(reason, state)
        {:error, reason}
    end
  end

  defp start_workers(entities, start_worker_fun, prev_total) do
    Enum.reduce_while(entities, {:ok, prev_total}, fn
      entity, {:ok, acc_total} ->
        case start_worker_fun.(entity) do
          {:ok, _pid} -> {:cont, {:ok, acc_total + 1}}
          {:error, {:already_started, _pid}} -> {:cont, {:ok, acc_total + 1}}
          {:error, _reason} = error -> {:halt, error}
        end
    end)
  end

  defp log_error(reason, state) do
    log(:warn, "executing #{inspect(state.start_worker_fun)} at startup failed", reason: reason)
  end

  defp log(level, message, metadata) do
    metadata_format = &"#{elem(&1, 0)}=[#{elem(&1, 1)}]"
    metadata_string = Enum.map_join(metadata, " ", metadata_format)

    Logger.log(level, metadata_string <> " " <> message)
  end

  defp check_function(args, name, arity) do
    unless fun = Keyword.get(args, name) do
      raise "Missing function #{name}"
    end

    unless is_function(fun) do
      raise "Invalid function #{name}"
    end

    unless :erlang.fun_info(fun)[:arity] == arity do
      raise "Wrong function arity #{fun}: #{arity} needed"
    end

    args
  end
end
