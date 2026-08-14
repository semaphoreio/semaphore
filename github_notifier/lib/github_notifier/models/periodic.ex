defmodule GithubNotifier.Models.Periodic do
  defstruct [:id, :commit_status]

  require Logger

  @cache_ttl :timer.minutes(5)

  @doc """
  Fetches the commit status policy of a scheduler task. Successful lookups are
  cached for a few minutes since one pipeline can produce many notifications.
  Returns nil when the task is gone or the scheduler is unavailable, so the
  caller falls back to the project settings.
  """
  @spec find(String.t()) :: %__MODULE__{} | nil
  def find(id) do
    case Cachex.get(:task_policy, id) do
      {:ok, %__MODULE__{} = periodic} ->
        periodic

      _ ->
        Watchman.benchmark("fetch_periodic.duration", fn ->
          describe(id)
        end)
    end
  end

  defp describe(id) do
    {:ok, channel} =
      GRPC.Stub.connect(Application.fetch_env!(:github_notifier, :scheduler_grpc_endpoint))

    req = struct(InternalApi.PeriodicScheduler.DescribeRequest, id: id)

    case InternalApi.PeriodicScheduler.PeriodicService.Stub.describe(channel, req,
           timeout: 30_000
         ) do
      {:ok, %{status: %{code: :OK}, periodic: periodic}} when not is_nil(periodic) ->
        %__MODULE__{id: periodic.id, commit_status: periodic.commit_status}
        |> tap(&Cachex.put(:task_policy, id, &1, ttl: @cache_ttl))

      {:ok, response} ->
        Logger.info("Periodic #{id} not resolvable: #{inspect(response.status)}")
        Watchman.increment("fetch_periodic.failed")
        nil

      {:error, error} ->
        Logger.error("Periodic #{id} describe failed: #{inspect(error)}")
        Watchman.increment("fetch_periodic.failed")
        nil
    end
  end
end
