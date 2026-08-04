defmodule GithubNotifier.StatusSender do
  @moduledoc """
  Delivers commit statuses, serialized per check (repository/sha/pipeline/context).

  Statuses for the same check are routed to the same worker, so within this
  instance they are sent one at a time, in order, and a `pending` status is
  dropped when a terminal status (success/failure) was already sent for the
  same check. The in-process checks are a fast path only: the authoritative,
  cross-instance guard lives in Redis (`GithubNotifier.StatusGuard`) — each
  delivery holds a per-check lease and the last delivered state is shared, so
  a stale pending is skipped even when the terminal status was sent by a
  sibling instance. On any guard error delivery proceeds unguarded.

  A status is only marked as sent after a successful delivery; transport
  failures return `:error` so the caller can fail the message and have it
  redelivered.

  Callers block until their own delivery attempt finishes. Each attempt is
  bounded by the connect and RPC timeouts, so a delivery is never failed
  just because it waited in the worker queue behind a slow one.

  Each worker holds a single long-lived gRPC channel and reuses it across
  deliveries, reconnecting when the connection is down, the configured
  endpoint changed, or the previous delivery failed at the transport level.
  """

  use Supervisor

  @pool_size 8

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children =
      for index <- 0..(@pool_size - 1) do
        name = worker_name(index)
        Supervisor.child_spec({GithubNotifier.StatusSender.Worker, name}, id: name)
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  def send_status(status_key, data, request_id) do
    GenServer.call(worker_for(status_key), {:send, status_key, data, request_id}, :infinity)
  end

  def worker_for(status_key), do: worker_name(:erlang.phash2(status_key, @pool_size))

  defp worker_name(index), do: :"github_notifier_status_sender_#{index}"
end

defmodule GithubNotifier.StatusSender.Worker do
  @moduledoc false

  use GenServer
  require Logger

  alias GithubNotifier.StatusGuard

  @terminal_states ["success", "failure"]
  @cache_ttl :timer.hours(5)
  @busy_poll_max_ms 3_000

  # repository_hub replied with an application error — the provider call
  # definitively did not send, so releasing the delivery lease is safe.
  @rejected_grpc_statuses [
    GRPC.Status.invalid_argument(),
    GRPC.Status.not_found(),
    GRPC.Status.permission_denied(),
    GRPC.Status.resource_exhausted(),
    GRPC.Status.failed_precondition()
  ]

  def start_link(name) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  @impl true
  def init(_arg), do: {:ok, %{channel: nil, endpoint: nil}}

  @impl true
  def handle_call({:send, status_key, data, request_id}, _from, state) do
    {reply, state} = deliver(status_key, data, request_id, state)
    {:reply, reply, state}
  end

  defp deliver(status_key, data, request_id, state) do
    dedupe_key = "#{status_key}/#{data.state}/#{data.description}"
    terminal_key = "terminal/#{status_key}"

    cond do
      Cachex.get!(:store, dedupe_key) ->
        Logger.info("[#{request_id}] Skipping Status: #{dedupe_key}")
        {:ok, state}

      data.state == "pending" && Cachex.get!(:store, terminal_key) ->
        Watchman.increment("set_commit_status.skipped_stale_pending")
        Logger.info("[#{request_id}] Skipping stale pending Status: #{dedupe_key}")
        {:ok, state}

      StatusGuard.delivered?(dedupe_key) ->
        Cachex.put!(:store, dedupe_key, true, ttl: @cache_ttl)

        Logger.info(
          "[#{request_id}] Skipping Status delivered by another instance: #{dedupe_key}"
        )

        {:ok, state}

      true ->
        guarded_send(status_key, dedupe_key, terminal_key, data, request_id, state)
    end
  end

  defp guarded_send(status_key, dedupe_key, terminal_key, data, request_id, state) do
    case claim_with_wait(status_key, data.state, busy_wait_budget()) do
      :skip ->
        Watchman.increment("set_commit_status.skipped_stale_pending")
        Cachex.put!(:store, terminal_key, true, ttl: @cache_ttl)

        Logger.info(
          "[#{request_id}] Skipping stale pending Status (cross-instance): #{dedupe_key}"
        )

        {:ok, state}

      :busy ->
        Watchman.increment("status_guard.busy")

        Logger.info(
          "[#{request_id}] Status delivery in flight on another instance: #{dedupe_key}"
        )

        {:error, state}

      {:error, reason} ->
        Watchman.increment("status_guard.unavailable")

        Logger.warning(
          "[#{request_id}] Status guard unavailable, delivering unguarded: #{inspect(reason)}"
        )

        send_unguarded(dedupe_key, terminal_key, data, request_id, state)

      {:ok, token} ->
        send_with_lease(status_key, dedupe_key, terminal_key, data, request_id, state, token)
    end
  end

  defp send_unguarded(dedupe_key, terminal_key, data, request_id, state) do
    Logger.info("[#{request_id}] Creating Status: #{dedupe_key}")

    case send_over_channel(dedupe_key, terminal_key, data, request_id, state) do
      {:ok, state} -> {:ok, state}
      {:error, _outcome, state} -> {:error, state}
    end
  end

  defp send_with_lease(status_key, dedupe_key, terminal_key, data, request_id, state, token) do
    Logger.info("[#{request_id}] Creating Status: #{dedupe_key}")

    case send_over_channel(dedupe_key, terminal_key, data, request_id, state) do
      {:ok, state} ->
        StatusGuard.finalize(status_key, data.state, token)
        StatusGuard.mark_delivered(dedupe_key)
        {:ok, state}

      {:error, :rejected, state} ->
        StatusGuard.release(status_key, token)
        {:error, state}

      {:error, :unknown, state} ->
        {:error, state}
    end
  end

  defp claim_with_wait(status_key, state_name, budget_ms) do
    case StatusGuard.claim(status_key, state_name) do
      {:busy, remaining} when budget_ms > 0 ->
        sleep =
          remaining
          |> max(200)
          |> min(@busy_poll_max_ms)
          |> min(budget_ms)
          |> Kernel.+(:rand.uniform(250))

        Process.sleep(sleep)
        claim_with_wait(status_key, state_name, budget_ms - sleep)

      {:busy, _remaining} ->
        :busy

      other ->
        other
    end
  end

  defp busy_wait_budget,
    do: Application.get_env(:github_notifier, :status_guard_busy_budget_ms, 30_000)

  defp send_over_channel(dedupe_key, terminal_key, data, request_id, state) do
    case ensure_channel(state) do
      {:ok, state} ->
        case create_status(data, state.channel) do
          :ok ->
            mark_sent(dedupe_key, terminal_key, data.state)
            Logger.info("[#{request_id}] Creating Status Finished: #{dedupe_key}")
            {:ok, state}

          :rejected ->
            {:error, :rejected, state}

          :transport_error ->
            {:error, :unknown, drop_channel(state)}
        end

      {:error, reason, state} ->
        report_failure(reason)
        {:error, :rejected, state}
    end
  end

  defp ensure_channel(state) do
    endpoint = Application.fetch_env!(:github_notifier, :repositoryhub_api_grpc_endpoint)

    if usable_channel?(state, endpoint) do
      {:ok, state}
    else
      state = drop_channel(state)

      case GRPC.Stub.connect(endpoint) do
        {:ok, channel} -> {:ok, %{state | channel: channel, endpoint: endpoint}}
        {:error, reason} -> {:error, reason, state}
      end
    end
  end

  defp usable_channel?(%{channel: nil}, _endpoint), do: false

  defp usable_channel?(%{channel: channel, endpoint: endpoint}, current_endpoint) do
    endpoint == current_endpoint && Process.alive?(channel.adapter_payload.conn_pid)
  end

  defp drop_channel(%{channel: nil} = state), do: state

  defp drop_channel(%{channel: channel} = state) do
    GRPC.Stub.disconnect(channel)
    %{state | channel: nil, endpoint: nil}
  end

  defp mark_sent(dedupe_key, terminal_key, state) do
    Cachex.put!(:store, dedupe_key, true, ttl: @cache_ttl)

    if state in @terminal_states do
      Cachex.put!(:store, terminal_key, true, ttl: @cache_ttl)
    end
  end

  defp create_status(data, channel) do
    Watchman.benchmark("create_status.duration", fn ->
      req =
        struct(InternalApi.Repository.CreateBuildStatusRequest,
          repository_id: data.repository_id,
          commit_sha: data.sha,
          status: map_status(data.state),
          url: data.url,
          description: data.description,
          context: data.context
        )

      Logger.debug(fn ->
        "Creating Status repository_id: #{req.repository_id}"
      end)

      Logger.debug(inspect(req))

      res =
        InternalApi.Repository.RepositoryService.Stub.create_build_status(channel, req,
          timeout: 30_000
        )

      Logger.debug("Received Create Status response")
      Logger.debug(inspect(res))

      handle_response(res)
    end)
  rescue
    error ->
      report_failure(error)
      :transport_error
  end

  defp handle_response({:ok, %{code: :OK}}) do
    Watchman.increment(
      internal: "set_commit_status.success",
      external: {"set_commit_status", [result: "success"]}
    )

    :ok
  end

  defp handle_response({:ok, _} = res) do
    report_failure(res)
    :rejected
  end

  defp handle_response({:error, %GRPC.RPCError{status: status} = error})
       when status in @rejected_grpc_statuses do
    report_failure(error)
    :rejected
  end

  defp handle_response(res) do
    report_failure(res)
    :transport_error
  end

  defp report_failure(res) do
    Watchman.increment(
      internal: "set_commit_status.failure",
      external: {"set_commit_status", [result: "failure"]}
    )

    Logger.error("Failed to create status: #{inspect(res)}")

    :error
  end

  defp map_status("success"), do: :SUCCESS
  defp map_status("pending"), do: :PENDING
  defp map_status("failure"), do: :FAILURE
end
