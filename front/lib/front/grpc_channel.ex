defmodule Front.GrpcChannel do
  @moduledoc """
  Reuses gRPC connections across calls.

  `GRPC.Stub.connect/1` opens a new HTTP/2 connection (TCP handshake plus a
  gun process) on every call, and the connection lives until the calling
  process exits. `connect/1` has the same contract, but hands out a
  connection from a small per-endpoint pool owned by this process.

  - Each endpoint gets `pool_size` connections; a caller is mapped to one of
    them by its pid, so concurrent requests spread over the pool.
  - Connections are replaced after `max_age_ms`, so traffic keeps spreading
    over backend pods behind a Kubernetes Service. Exactly one caller dials
    the replacement; everyone else keeps using the old connection meanwhile.
    Replaced connections are shut down gracefully after `close_grace_ms`.
  - A connection that goes down is evicted right away.
  - `pool_size: 0` disables reuse: `connect/1` is `GRPC.Stub.connect/1` and
    `release/1` is `GRPC.Stub.disconnect/1`, exactly as before.

  gun delivers responses to the process that made the request, so a single
  connection can be used from many processes at once.

  Rules for callers:

  - Use the channel for one call (or a few calls in a row), then drop it.
    Do not keep it across a long loop: it can be closed `close_grace_ms`
    after it was replaced. Long loops (paginated exports) connect per page,
    or use `call/2`.
  - Never call `GRPC.Stub.disconnect/1` on a channel from here; call
    `release/1`.
  - `call/2` retries once on a fresh connection when the pooled one failed
    at the transport level (stream reset, connection error, gun process
    down). Use it only for idempotent requests. Deadlines and errors
    returned by the server are never retried.
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

    if size > 0 do
      pooled_connect({endpoint, :erlang.phash2(self(), size)})
    else
      GRPC.Stub.connect(endpoint)
    end
  end

  @doc """
  Gives a channel back. Closes it when pooling is off, otherwise no-op.
  """
  @spec release(GRPC.Channel.t()) :: :ok
  def release(channel) do
    if pool_size() == 0, do: GRPC.Stub.disconnect(channel)
    :ok
  end

  @doc """
  Connects to `endpoint` and runs `fun.(channel)`. If the result is a
  transport-level error from a pooled connection, evicts that connection and
  runs `fun` once more on a fresh one. For idempotent requests only.
  """
  @spec call(String.t(), (GRPC.Channel.t() -> result)) :: result | {:error, any()}
        when result: any()
  def call(endpoint, fun) do
    with {:ok, channel} <- connect(endpoint) do
      result = fun.(channel)

      if pool_size() > 0 and transport_error?(result) do
        Logger.info("gRPC call failed on a pooled connection, retrying once: #{inspect(result)}")
        evict(channel)

        with {:ok, fresh} <- connect(endpoint), do: fun.(fresh)
      else
        release(channel)
        result
      end
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

  # gun.await maps gun_error and the connection process going down to
  # {:stream_error, _}, {:connection_error, _} and {:down, _}; the gun adapter
  # turns those into an RPCError whose message starts with the inspected tag.
  # Errors sent by the server arrive as trailers and never look like this.
  @transport_reasons [":stream_error", ":connection_error", ":down"]
  @unknown GRPC.Status.unknown()
  @internal GRPC.Status.internal()

  @doc false
  def transport_error?({:error, %GRPC.RPCError{status: status, message: message}})
      when status in [@unknown, @internal] and is_binary(message) do
    String.starts_with?(message, @transport_reasons)
  end

  def transport_error?(_), do: false

  defp pooled_connect(key) do
    now = System.monotonic_time(:millisecond)

    case lookup(key) do
      {:ok, entry = {_, channel, created_at, pid}} ->
        cond do
          not Process.alive?(pid) ->
            delete_exact(entry)
            pooled_connect(key)

          now - created_at < max_age_ms() ->
            {:ok, channel}

          claim_refresh(entry, now) ->
            refresh(key, entry, now)

          true ->
            # Someone else is dialing the replacement.
            {:ok, channel}
        end

      :empty ->
        open(key, now)

      :unavailable ->
        GRPC.Stub.connect(elem(key, 0))
    end
  end

  # Only the caller that bumps the exact entry's timestamp dials. Others see a
  # fresh timestamp and keep using the old connection until the swap.
  defp claim_refresh({key, _channel, created_at, pid}, now) do
    match = {key, :"$1", created_at, pid}
    replacement = {{{:const, key}, :"$1", now, {:const, pid}}}

    safe(fn -> :ets.select_replace(@table, [{match, [], [replacement]}]) end, 0) == 1
  end

  defp refresh(key = {endpoint, _}, {_, old_channel, _, old_pid}, now) do
    case GRPC.Stub.connect(endpoint) do
      {:ok, channel} ->
        pid = conn_pid(channel)
        safe(fn -> :ets.insert(@table, {key, channel, now, pid}) end, false)
        adopt(pid)
        GenServer.cast(__MODULE__, {:retire, old_pid})
        {:ok, channel}

      {:error, reason} ->
        # Keep serving the old connection; it is still alive.
        Logger.info("gRPC connection refresh failed: #{inspect(reason)}")
        {:ok, old_channel}
    end
  end

  defp open(key = {endpoint, _}, now) do
    case GRPC.Stub.connect(endpoint) do
      {:ok, channel} ->
        pid = conn_pid(channel)

        if safe(fn -> :ets.insert_new(@table, {key, channel, now, pid}) end, false) do
          adopt(pid)
          {:ok, channel}
        else
          # Lost the race: use the winner's connection, close ours.
          case lookup(key) do
            {:ok, {_, winner, _, _}} ->
              GRPC.Stub.disconnect(channel)
              {:ok, winner}

            _ ->
              {:ok, channel}
          end
        end

      error ->
        error
    end
  end

  # Stop handing the connection out. It is closed gracefully later, so other
  # calls still running on it are not cut off if it is in fact healthy.
  defp evict(channel) do
    case conn_pid(channel) do
      pid when is_pid(pid) ->
        safe(fn -> :ets.match_delete(@table, {:_, :_, :_, pid}) end, true)
        GenServer.cast(__MODULE__, {:retire, pid})

      _ ->
        :ok
    end
  end

  defp lookup(key) do
    case safe(fn -> :ets.lookup(@table, key) end, :unavailable) do
      [entry] -> {:ok, entry}
      [] -> :empty
      :unavailable -> :unavailable
    end
  end

  defp delete_exact(entry), do: safe(fn -> :ets.delete_object(@table, entry) end, true)

  # The table goes away with the holder; fall back instead of crashing callers.
  defp safe(fun, fallback) do
    fun.()
  rescue
    ArgumentError -> fallback
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
