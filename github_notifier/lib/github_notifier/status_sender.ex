defmodule GithubNotifier.StatusSender do
  @moduledoc """
  Delivers commit statuses, serialized per check (repository/sha/pipeline/context).

  Statuses for the same check are always routed to the same worker, so they
  are sent one at a time, in order. A `pending` status is dropped when a
  terminal status (success/failure) was already sent for the same check,
  since delivering it would leave the commit check pending forever.
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
    worker = worker_name(:erlang.phash2(status_key, @pool_size))

    GenServer.call(worker, {:send, status_key, data, request_id}, 35_000)
  end

  defp worker_name(index), do: :"github_notifier_status_sender_#{index}"
end

defmodule GithubNotifier.StatusSender.Worker do
  @moduledoc false

  use GenServer
  require Logger

  @terminal_states ["success", "failure"]
  @cache_ttl :timer.hours(5)

  def start_link(name) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:send, status_key, data, request_id}, _from, state) do
    deliver(status_key, data, request_id)

    {:reply, :ok, state}
  end

  defp deliver(status_key, data, request_id) do
    dedupe_key = "#{status_key}/#{data.state}/#{data.description}"
    terminal_key = "terminal/#{status_key}"

    cond do
      Cachex.get!(:store, dedupe_key) ->
        Logger.info("[#{request_id}] Skipping Status: #{dedupe_key}")

      data.state == "pending" && Cachex.get!(:store, terminal_key) ->
        Watchman.increment("set_commit_status.skipped_stale_pending")
        Logger.info("[#{request_id}] Skipping stale pending Status: #{dedupe_key}")

      true ->
        Logger.info("[#{request_id}] Creating Status: #{dedupe_key}")
        create_status(data)
        mark_sent(dedupe_key, terminal_key, data.state)
        Logger.info("[#{request_id}] Creating Status Finished: #{dedupe_key}")
    end
  end

  defp mark_sent(dedupe_key, terminal_key, state) do
    Cachex.put!(:store, dedupe_key, true, ttl: @cache_ttl)

    if state in @terminal_states do
      Cachex.put!(:store, terminal_key, true, ttl: @cache_ttl)
    end
  end

  defp create_status(data) do
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

      {:ok, channel} =
        GRPC.Stub.connect(
          Application.fetch_env!(:github_notifier, :repositoryhub_api_grpc_endpoint)
        )

      Logger.debug(fn ->
        "Creating Status repository_id: #{req.repository_id}"
      end)

      Logger.debug(inspect(req))

      res =
        InternalApi.Repository.RepositoryService.Stub.create_build_status(channel, req,
          timeout: 30_000
        )

      case res do
        {:ok, %{code: :OK}} ->
          Watchman.increment(
            internal: "set_commit_status.success",
            external: {"set_commit_status", [result: "success"]}
          )

        _ ->
          Watchman.increment(
            internal: "set_commit_status.failure",
            external: {"set_commit_status", [result: "failure"]}
          )
      end

      Logger.debug("Received Create Status response")
      Logger.debug(inspect(res))

      :ok
    end)
  rescue
    error ->
      Watchman.increment(
        internal: "set_commit_status.failure",
        external: {"set_commit_status", [result: "failure"]}
      )

      Logger.error("Failed to create status: #{inspect(error)}")

      :error
  end

  alias InternalApi.Repository.CreateBuildStatusRequest.Status
  defp map_status("success"), do: Status.value(:SUCCESS)
  defp map_status("pending"), do: Status.value(:PENDING)
  defp map_status("failure"), do: Status.value(:FAILURE)
end
