defmodule GithubNotifier.Models.Periodic do
  defstruct [:id, :skip_scheduled_run_notifications, :skip_manual_run_notifications]

  require Logger

  @cache_ttl :timer.minutes(5)
  @not_found_cache_ttl :timer.seconds(30)
  @unreachable_cache_ttl :timer.seconds(5)
  @rpc_timeout 2_000

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
    {:ok, channel} =
      GRPC.Stub.connect(Application.fetch_env!(:github_notifier, :scheduler_grpc_endpoint))

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
        Watchman.increment("fetch_periodic.failed")
        Cachex.put(:task_policy, id, :not_found, ttl: @not_found_cache_ttl)
        nil

      {:error, error} ->
        Logger.error("Periodic #{id} describe failed: #{inspect(error)}")
        Watchman.increment("fetch_periodic.failed")
        Cachex.put(:task_policy, id, :not_found, ttl: @unreachable_cache_ttl)
        nil
    end
  end
end
