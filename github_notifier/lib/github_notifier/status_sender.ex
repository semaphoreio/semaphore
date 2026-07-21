defmodule GithubNotifier.StatusSender do
  @moduledoc """
  Delivers commit statuses, serialized per check (repository/sha/pipeline/context).

  Statuses for the same check are always routed to the same worker, so they
  are sent one at a time, in order. A `pending` status is dropped when a
  terminal status (success/failure) was already sent for the same check,
  since delivering it would leave the commit check pending forever.

  A status is only marked as sent after a successful delivery; transport
  failures return `:error` so the caller can fail the message and have it
  redelivered.

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
    GenServer.call(worker_for(status_key), {:send, status_key, data, request_id}, 35_000)
  end

  def worker_for(status_key), do: worker_name(:erlang.phash2(status_key, @pool_size))

  defp worker_name(index), do: :"github_notifier_status_sender_#{index}"
end

defmodule GithubNotifier.StatusSender.Worker do
  @moduledoc false

  use GenServer
  require Logger

  alias InternalApi.Repository.CreateBuildStatusResponse

  @terminal_states ["success", "failure"]
  @cache_ttl :timer.hours(5)

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

      true ->
        Logger.info("[#{request_id}] Creating Status: #{dedupe_key}")
        send_over_channel(dedupe_key, terminal_key, data, request_id, state)
    end
  end

  defp send_over_channel(dedupe_key, terminal_key, data, request_id, state) do
    case ensure_channel(state) do
      {:ok, state} ->
        case create_status(data, state.channel) do
          :ok ->
            mark_sent(dedupe_key, terminal_key, data.state)
            Logger.info("[#{request_id}] Creating Status Finished: #{dedupe_key}")
            {:ok, state}

          :error ->
            {:error, state}

          :transport_error ->
            {:error, drop_channel(state)}
        end

      {:error, reason, state} ->
        report_failure(reason)
        {:error, state}
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
        InternalApi.Repository.CreateBuildStatusRequest.new(
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

  defp handle_response({:ok, %{code: code}} = res) do
    if CreateBuildStatusResponse.Code.key(code) == :OK do
      Watchman.increment(
        internal: "set_commit_status.success",
        external: {"set_commit_status", [result: "success"]}
      )

      :ok
    else
      report_failure(res)
    end
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

  alias InternalApi.Repository.CreateBuildStatusRequest.Status
  defp map_status("success"), do: Status.value(:SUCCESS)
  defp map_status("pending"), do: Status.value(:PENDING)
  defp map_status("failure"), do: Status.value(:FAILURE)
end
