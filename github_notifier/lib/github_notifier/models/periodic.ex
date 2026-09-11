defmodule GithubNotifier.Models.Periodic do
  defstruct [:id, :skip_scheduled_run_notifications, :skip_manual_run_notifications]

  require Logger

  @cache_ttl :timer.minutes(5)
  @not_found_cache_ttl :timer.seconds(30)
  @unreachable_cache_ttl :timer.seconds(5)
  @rpc_timeout 1_500
  # A caller must outlast the RPC deadline, or it kills this process before the
  # failure branch can cache the result and emit its metric.
  @yield_grace 500

  @doc "How long a caller should wait for find/1 before giving up on it."
  @spec lookup_budget() :: pos_integer()
  def lookup_budget, do: @rpc_timeout + @yield_grace

  @doc """
  Fetches the notification skip flags of a scheduler task. Successful lookups
  are cached for a few minutes since one pipeline produces many notifications,
  and a task the scheduler doesn't know about is cached briefly so a deleted
  task isn't re-queried on every event.

  Returns nil when the task can't be resolved, which means "send the status".
  """
  @spec find(String.t()) :: %__MODULE__{} | nil
  def find(id) do
    case Cachex.get(:task_policy, id) do
      {:ok, %__MODULE__{} = periodic} ->
        periodic

      {:ok, :not_found} ->
        nil

      _ ->
        Watchman.benchmark("fetch_periodic.duration", fn -> describe(id) end)
    end
  end

  defp describe(id) do
    case GRPC.Stub.connect(Application.fetch_env!(:github_notifier, :scheduler_grpc_endpoint)) do
      {:ok, channel} -> describe(id, channel)
      {:error, error} -> unreachable(id, error)
    end
  end

  defp describe(id, channel) do
    req = struct(InternalApi.PeriodicScheduler.DescribeRequest, id: id)

    case InternalApi.PeriodicScheduler.PeriodicService.Stub.describe(channel, req,
           timeout: @rpc_timeout
         ) do
      {:ok, %{status: %{code: :OK}, periodic: periodic}} when not is_nil(periodic) ->
        %__MODULE__{
          id: periodic.id,
          skip_scheduled_run_notifications: periodic.skip_scheduled_run_notifications,
          skip_manual_run_notifications: periodic.skip_manual_run_notifications
        }
        |> tap(&Cachex.put(:task_policy, id, &1, ttl: @cache_ttl))

      {:ok, response} ->
        Logger.info("Periodic #{id} not resolvable: #{inspect(response.status)}")
        Watchman.increment("fetch_periodic.not_found")
        Cachex.put(:task_policy, id, :not_found, ttl: @not_found_cache_ttl)
        nil

      {:error, error} ->
        unreachable(id, error)
    end
  end

  defp unreachable(id, error) do
    Logger.error("Periodic #{id} describe failed: #{inspect(error)}")
    Watchman.increment("fetch_periodic.unreachable")
    Cachex.put(:task_policy, id, :not_found, ttl: @unreachable_cache_ttl)
    nil
  end
end
