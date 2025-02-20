defmodule Zebra.Apis.InternalTaskApi do
  require Logger

  use GRPC.Server, service: InternalApi.Task.TaskService.Service
  use Sentry.Grpc, service: InternalApi.Task.TaskService.Service

  alias Zebra.Apis.InternalTaskApi.Serializer
  alias InternalApi.Task.DescribeResponse
  alias InternalApi.Task.DescribeManyResponse

  alias Zebra.Models.Task, as: T

  def schedule(req, _call) do
    observe("schedule", fn ->
      wf_id = req.wf_id
      hook_id = req.hook_id
      ppl_id = req.ppl_id
      token = req.request_token

      Logger.info("Schedule: wf: #{wf_id}, ppl: #{ppl_id}, hook: #{hook_id}, token: #{token}")

      with :ok <- Zebra.Apis.InternalTaskApi.Schedule.validate(req),
           {:ok, task} <- Zebra.Apis.InternalTaskApi.Schedule.schedule(req) do
        observe("schedule.serialize_response", fn ->
          InternalApi.Task.ScheduleResponse.new(task: Serializer.serialize(task))
        end)
      else
        {:error, :aborted} ->
          raise GRPC.RPCError, status: :aborted

        {:error, :invalid_argument, msg} ->
          raise GRPC.RPCError, status: :invalid_argument, message: msg
      end
    end)
  end

  def describe(req, _call) do
    observe("describe", fn ->
      case T.find_by_id_or_request_token(req.task_id) do
        {:ok, task} ->
          DescribeResponse.new(task: Serializer.serialize(task))

        {:error, :not_found} ->
          raise GRPC.RPCError, status: :not_found
      end
    end)
  end

  def describe_many(req, _call) do
    observe("describe_many", fn ->
      {:ok, tasks} = T.find_many_by_id_or_request_token(req.task_ids)

      DescribeManyResponse.new(tasks: Serializer.serialize_many(tasks))
    end)
  end

  def terminate(req, _call) do
    observe("terminate", fn ->
      alias InternalApi.Task.TerminateResponse

      Logger.info("Terminate: task_id #{req.task_id}")

      with {:ok, task} <- T.find_by_id_or_request_token(req.task_id),
           :ok <- Zebra.Workers.JobStopper.request_stop_for_all_jobs_in_task_async(task) do
        Logger.info("Terminate: Task terminated #{req.task_id}")

        TerminateResponse.new(message: "Terminated #{task.id}")
      else
        {:error, :not_found} ->
          Logger.info("Terminate: Task not-found #{req.task_id}")

          raise GRPC.RPCError, status: :not_found
      end
    end)
  end

  #
  # Utils
  #

  defp observe(action_name, f) do
    Watchman.benchmark("internal_task_api.#{action_name}.duration", fn ->
      try do
        result = f.()

        Watchman.increment("internal_task_api.#{action_name}.success")

        result
      rescue
        e ->
          Watchman.increment("internal_task_api.#{action_name}.failure")
          Kernel.reraise(e, __STACKTRACE__)
      end
    end)
  end
end
