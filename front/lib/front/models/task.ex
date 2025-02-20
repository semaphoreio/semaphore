defmodule Front.Models.Task do
  alias InternalApi.Task.Task
  alias InternalApi.Task.TaskService

  def describe_many(ids) do
    Watchman.benchmark("task.find_many.duration", fn ->
      {:ok, channel} = GRPC.Stub.connect(Application.fetch_env!(:front, :task_grpc_endpoint))

      request = InternalApi.Task.DescribeManyRequest.new(task_ids: ids)

      options = [
        timeout: 30_000
      ]

      case TaskService.Stub.describe_many(channel, request, options) do
        {:ok, response} ->
          response.tasks |> atomify_enums

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  def atomify_enums(tasks) do
    tasks
    |> Enum.map(fn task ->
      task
      |> Map.put(:state, task.state |> Task.State.key())
      |> Map.put(:result, task.result |> Task.Result.key())
      |> Map.put(
        :jobs,
        task.jobs
        |> Enum.map(fn job ->
          job
          |> Map.put(:state, job.state |> Task.Job.State.key())
          |> Map.put(:result, job.result |> Task.Job.Result.key())
        end)
      )
    end)
  end

  @doc """
  Tests if any of the jobs in the tasks is created, but waiting to start.

  Threshold: Some waiting time always exists in the system. But not every
  interval is worthy to be a notification to the user.

  example:

    waiting_to_start?(tasks, 20)
  """
  def waiting_to_start?(tasks, treshold: treshold_in_secs) do
    all_jobs = tasks |> Enum.map(fn t -> t.jobs end) |> List.flatten()

    #
    # The jobs in the Task API only have an ENQUEUED, RUNNING, DONE state, so
    # knowning the exact state of the jobs is tricky.
    #
    # Ideally, we would have 'waiting-for-quota' and 'waiting-for-capacity' in
    # the state list. However, adding these states can't be done easily without
    # the risk of breaking other upstream APIs.
    #
    # Luckily for us, the timestamps in the jobs are more verbose. There are
    # three timestamps that we care about:
    #
    # - created_at
    # - enqueued_at (started to wait for quota)
    # - scheduled_at (started to wait for capacity)
    #
    # To get the jobs we want, we are going to filter out by these criteria:
    #
    # - The job is ENQUEUED
    # - The job has a enqueued_at timestamp
    # - The job doesn't have a scheduled_at timestamp
    #
    # This will give us only the jobs that are waiting for quota.
    #
    enqueued_jobs =
      all_jobs
      |> Enum.filter(fn j ->
        j.state == :ENQUEUED && j.enqueued_at != nil && j.scheduled_at == nil
      end)

    # Next, we don't want to report that we are waiting for quota for jobs that
    # are in that state for less then several seconds.
    #
    # We filter out every job that is waiting less than the provided treshold.

    now_epoch = DateTime.utc_now() |> DateTime.to_unix()
    waiting_times = enqueued_jobs |> Enum.map(fn j -> now_epoch - j.enqueued_at.seconds end)

    # If the maximal waiting time is larger than the treshold, we are waiting.
    # Otherwise, we are not waiting.
    max(waiting_times) > treshold_in_secs
  end

  defp max([]), do: 0
  defp max(list), do: Enum.max(list)
end
