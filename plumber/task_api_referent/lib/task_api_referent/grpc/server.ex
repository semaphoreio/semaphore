defmodule TaskApiReferent.Grpc.Server do
  @moduledoc """
  GRPC server that accepts GRPC Client's calls
  Provides 'schedule' method for executing tasks and setting their status,
  'describe' method for accessing task and its jobs statuses and
  'terminate' method fot terminating task's execution.
  """

  use GRPC.Server, service: InternalApi.Task.TaskService.Service

  alias Util.{Proto, Metrics}
  alias TaskApiReferent.{Actions, Service}
  alias Google.Protobuf.Timestamp
  alias InternalApi.Task.{ScheduleResponse, DescribeResponse, DescribeManyResponse,
                          TerminateResponse}

  def schedule(schedule_request, _stream) do
    Metrics.benchmark("ReferentTaskApi.schedule", __MODULE__,  fn ->
      with {:ok, params} <- Proto.to_map(schedule_request),
           {:ok, task}   <- Actions.schedule(params)
      do
        %{task: task} |> Proto.deep_new!(ScheduleResponse, transformations: tf())
      end
    end)
  end


  def describe(request, _stream) do
    Metrics.benchmark("ReferentTaskApi.describe", __MODULE__,  fn ->
      case Service.Task.get_description(request.task_id) do
      {:ok, task} ->
        %{task: task} |> Proto.deep_new!(DescribeResponse, transformations: tf())
      {:error, msg = "'task_id' parameter" <> _rest} ->
        raise GRPC.RPCError, status: GRPC.Status.not_found, message: msg
      end
    end)
  end


  def describe_many(request, _stream) do
    Metrics.benchmark("ReferentTaskApi.describe_many", __MODULE__,  fn ->
      with {:ok, tasks} <- Actions.describe_many(request.task_ids)
      do
        %{tasks: tasks} |> Proto.deep_new!(DescribeManyResponse, transformations: tf())
      end
    end)
  end


  def terminate(request, _stream) do
    Metrics.benchmark("ReferentTaskApi.describe", __MODULE__,  fn ->
      with {:ok, task} <- Service.Task.get(request.task_id),
           {:ok, _res} <- Actions.terminate(task)
      do
        %{message: "Task marked for termination."}
        |> Proto.deep_new!(TerminateResponse)
      else
         {:error, msg = "'task_id' parameter" <> _rest} ->
           raise GRPC.RPCError, status: GRPC.Status.not_found, message: msg
      end
    end)
  end


  defp tf(), do: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}

  def date_time_to_timestamps(_field_name, nil), do: %{seconds: 0, nanos: 0}
  def date_time_to_timestamps(_field_name, date_time = %DateTime{}) do
    %{}
    |> Map.put(:seconds, DateTime.to_unix(date_time, :second))
    |> Map.put(:nanos, elem(date_time.microsecond, 0) * 1_000)
  end
  def date_time_to_timestamps(_field_name, value), do: value
end
