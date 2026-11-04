defmodule Front.GrpcChannel do
  @moduledoc """
  Reuses gRPC connections across calls.

  `GRPC.Stub.connect/1` opens a new HTTP/2 connection (TCP handshake plus a
  gun process) on every call, and the connection lives until the calling
  process exits. `connect/1` has the same contract, but hands out a
  connection from a small per-endpoint pool owned by this process.

  - Each endpoint gets `pool_size` connections; a caller is mapped to one of
    them by its pid, so concurrent requests spread over the pool.
  - Connections are retired after `max_age_ms`, so traffic keeps spreading
    over backend pods behind a Kubernetes Service. Retired connections are
    shut down gracefully after a grace period, letting in-flight calls end.
  - A connection that goes down is evicted right away; the next call opens
    a fresh one.
  - `pool_size: 0` disables reuse and falls back to `GRPC.Stub.connect/1`.

  gun delivers responses to the process that made the request, so a single
  connection can be used from many processes at once.

  Callers must not call `GRPC.Stub.disconnect/1` on a pooled channel.
  """

  use GenServer
  require Logger

  @table __MODULE__
  @default_pool_size 4
  @default_max_age_ms 30_000
  @default_close_grace_ms 120_000

  @spec connect(String.t()) :: {:ok, GRPC.Channel.t()} | {:error, any()}
  def connect(endpoint) do
    size = pool_size()

    if size > 0 and table_ready?() do
      key = {endpoint, :erlang.phash2(self(), size)}
      now = System.monotonic_time(:millisecond)

      case :ets.lookup(@table, key) do
        [{^key, channel, created_at, pid} = entry] ->
          if now - created_at < max_age_ms() and Process.alive?(pid) do
            {:ok, channel}
          else
            retire(entry)
            open(key, now)
          end

        [] ->
          open(key, now)
      end
    else
      GRPC.Stub.connect(endpoint)
    end
  end

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc false
  def pool_size, do: config(:pool_size, @default_pool_size)

  defp max_age_ms, do: config(:max_age_ms, @default_max_age_ms)
  defp close_grace_ms, do: config(:close_grace_ms, @default_close_grace_ms)

  defp config(key, default) do
    :front |> Application.get_env(__MODULE__, []) |> Keyword.get(key, default)
  end

  defp table_ready?, do: :ets.whereis(@table) != :undefined

  defp open(key = {endpoint, _}, now) do
    case GRPC.Stub.connect(endpoint) do
      {:ok, channel} ->
        pid = conn_pid(channel)

        # Only one caller wins the slot. A loser keeps its own connection for
        # this call, owned by itself as before, so it is closed when it exits.
        if is_pid(pid) and :ets.insert_new(@table, {key, channel, now, pid}) do
          adopt(pid)
        end

        {:ok, channel}

      error ->
        error
    end
  end

  defp adopt(pid) do
    case Process.whereis(__MODULE__) do
      nil ->
        :ok

      holder ->
        # gun sends connection events (gun_down) to its owner, so the holder
        # must own it. Without this the connection would die with the caller.
        :ok = :gun.set_owner(pid, holder)
        GenServer.cast(holder, {:adopt, pid})
    end
  end

  defp retire(entry = {_, _, _, pid}) do
    if :ets.delete_object(@table, entry) do
      GenServer.cast(__MODULE__, {:retire, pid})
    end
  end

  defp conn_pid(%{adapter_payload: %{conn_pid: pid}}), do: pid
  defp conn_pid(_), do: nil

  # Server

  @impl true
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:adopt, pid}, state) do
    {:noreply, Map.put_new_lazy(state, pid, fn -> Process.monitor(pid) end)}
  end

  def handle_cast({:retire, pid}, state) do
    Process.send_after(self(), {:close, pid}, close_grace_ms())
    {:noreply, state}
  end

  @impl true
  def handle_info({:close, pid}, state) do
    # Graceful: in-flight streams finish (up to gun's closing timeout).
    :ets.match_delete(@table, {:_, :_, :_, pid})
    :gun.shutdown(pid)
    {:noreply, state}
  end

  def handle_info({:gun_down, pid, _protocol, reason, _killed}, state) do
    # The streams on it are already gone. Stop gun from reconnecting in the
    # background; the next caller opens a fresh connection.
    Logger.debug("gRPC connection down: #{inspect(reason)}")
    :ets.match_delete(@table, {:_, :_, :_, pid})
    :gun.close(pid)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    :ets.match_delete(@table, {:_, :_, :_, pid})
    {:noreply, Map.delete(state, pid)}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
