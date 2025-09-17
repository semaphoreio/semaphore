defmodule Scheduler.Grpc.Server do
  @moduledoc false

  use GRPC.Server, service: InternalApi.PeriodicScheduler.PeriodicService.Service

  alias Util.{Metrics, Proto}
  alias Scheduler.Actions

  alias InternalApi.PeriodicScheduler.{
    ApplyResponse,
    DescribeResponse,
    VersionResponse,
    ListResponse,
    DeleteResponse,
    PauseResponse,
    UnpauseResponse,
    RunNowResponse,
    LatestTriggersResponse,
    GetProjectIdResponse,
    HistoryResponse,
    PersistResponse,
    ListKeysetResponse
  }

  alias Google.Protobuf.Timestamp

  # Apply

  def apply(request, _stream) do
    Metrics.benchmark("PeriodicSch.apply", __MODULE__, fn ->
      with {:ok, params} <- Proto.to_map(request),
           {:ok, id} <- Actions.apply(params) do
        %{id: id, status: %{code: :OK}} |> Proto.deep_new!(ApplyResponse)
      else
        {:error, {code, message}} ->
          %{status: %{code: code, message: to_str(message)}}
          |> Proto.deep_new!(ApplyResponse)
      end
    end)
  end

  # Persist

  def persist(request, _stream) do
    Metrics.benchmark("PeriodicSch.persist", __MODULE__, fn ->
      request = %{
        request
        | state: InternalApi.PeriodicScheduler.PersistRequest.ScheduleState.value(request.state)
      }

      with {:ok, params} <- Proto.to_map(request),
           {:ok, periodic} <- Actions.persist(params) do
        %{periodic: periodic, status: %{code: :OK}}
        |> Proto.deep_new!(PersistResponse,
          transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
        )
      else
        {:error, {code, message}} ->
          %{status: %{code: code, message: to_str(message)}}
          |> Proto.deep_new!(PersistResponse)
      end
    end)
  end

  # Pause

  def pause(request, _stream) do
    Metrics.benchmark("PeriodicSch.pause", __MODULE__, fn ->
      with {:ok, params} <- Proto.to_map(request),
           {:ok, msg} <- Actions.pause(params) do
        %{status: %{code: :OK, message: msg}} |> Proto.deep_new!(PauseResponse)
      else
        {:error, {code, message}} ->
          %{status: %{code: code, message: to_str(message)}}
          |> Proto.deep_new!(PauseResponse)
      end
    end)
  end

  # Unpause

  def unpause(request, _stream) do
    Metrics.benchmark("PeriodicSch.unpause", __MODULE__, fn ->
      with {:ok, params} <- Proto.to_map(request),
           {:ok, msg} <- Actions.unpause(params) do
        %{status: %{code: :OK, message: msg}} |> Proto.deep_new!(UnpauseResponse)
      else
        {:error, {code, message}} ->
          %{status: %{code: code, message: to_str(message)}}
          |> Proto.deep_new!(UnpauseResponse)
      end
    end)
  end

  # RunNow

  def run_now(request, _stream) do
    Metrics.benchmark("PeriodicSch.run_now", __MODULE__, fn ->
      with {:ok, params} <- Proto.to_map(request),
           {:ok, desc} <- Actions.run_now(params) do
        desc
        |> Map.merge(%{status: %{code: :OK}})
        |> Proto.deep_new!(
          RunNowResponse,
          transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
        )
      else
        {:error, {code, message}} ->
          %{status: %{code: code, message: to_str(message)}}
          |> Proto.deep_new!(RunNowResponse)

        {:error, %{code: code, message: message}} ->
          %{status: %{code: code, message: to_str(message)}}
          |> Proto.deep_new!(RunNowResponse)
      end
    end)
  end

  # Describe

  def describe(request, _stream) do
    Metrics.benchmark("PeriodicSch.describe", __MODULE__, fn ->
      with {:ok, params} <- Proto.to_map(request),
           {:ok, desc} <- Actions.describe(params) do
        desc
        |> Map.merge(%{status: %{code: :OK}})
        |> Proto.deep_new!(
          DescribeResponse,
          transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
        )
      else
        {:error, {code, message}} ->
          %{status: %{code: code, message: to_str(message)}}
          |> Proto.deep_new!(DescribeResponse)
      end
    end)
  end

  # LatestTriggers

  def latest_triggers(request, _stream) do
    Metrics.benchmark("PeriodicSch.latest_triggers", __MODULE__, fn ->
      with {:ok, params} <- Proto.to_map(request),
           {:ok, result} <- Actions.latest_triggers(params) do
        result
        |> Map.merge(%{"status" => %{"code" => :OK}})
        |> Proto.deep_new!(
          LatestTriggersResponse,
          transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}},
          string_keys_to_atoms: true
        )
      else
        {:error, {code, message}} ->
          %{status: %{code: code, message: to_str(message)}}
          |> Proto.deep_new!(LatestTriggersResponse)
      end
    end)
  end

  def history(request, _stream) do
    Metrics.benchmark("PeriodicSch.history", __MODULE__, fn ->
      filters = Map.take(request.filters || %{}, ~w(branch_name pipeline_file triggered_by)a)

      params =
        request
        |> Map.take(~w(periodic_id cursor_type cursor_value)a)
        |> Map.put(:filters, filters)

      case Actions.history(params) do
        {:ok, result} ->
          result
          |> Map.merge(%{"status" => %{"code" => :OK}})
          |> Proto.deep_new!(
            HistoryResponse,
            transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}},
            string_keys_to_atoms: true
          )

        {:error, {code, message}} ->
          %{status: %{code: code, message: to_str(message)}}
          |> Proto.deep_new!(HistoryResponse)
      end
    end)
  end

  # List

  def list(request, _stream) do
    Metrics.benchmark("PeriodicSch.list", __MODULE__, fn ->
      fields = ~w(organization_id project_id requester_id query page page_size order)a

      case request |> Map.take(fields) |> Actions.list() do
        {:ok, result} ->
          result
          |> Map.merge(%{status: %{code: :OK}})
          |> Proto.deep_new!(
            ListResponse,
            transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
          )

        {:error, {code, message}} ->
          %{status: %{code: code, message: to_str(message)}}
          |> Proto.deep_new!(ListResponse)
      end
    end)
  end

  # ListKeyset

  def list_keyset(request, _stream) do
    Metrics.benchmark("PeriodicSch.list_keyset", __MODULE__, fn ->
      fields = ~w(organization_id project_id query page_token page_size order direction)a

      case request |> Map.take(fields) |> Actions.list_keyset() do
        {:ok, result} ->
          result
          |> Map.merge(%{status: %{code: :OK}})
          |> Proto.deep_new!(
            ListKeysetResponse,
            transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
          )

        {:error, {code, message}} ->
          %{status: %{code: code, message: to_str(message)}}
          |> Proto.deep_new!(ListKeysetResponse)
      end
    end)
  end

  # Delete

  def delete(request, _stream) do
    Metrics.benchmark("PeriodicSch.delete", __MODULE__, fn ->
      with {:ok, params} <- Proto.to_map(request),
           {:ok, msg} <- Actions.delete(params) do
        %{status: %{code: :OK, message: msg}} |> Proto.deep_new!(DeleteResponse)
      else
        {:error, {code, message}} ->
          %{status: %{code: code, message: to_str(message)}}
          |> Proto.deep_new!(DeleteResponse)
      end
    end)
  end

  # GetProjectId

  def get_project_id(request, _stream) do
    Metrics.benchmark("PeriodicSch.get_project_id", __MODULE__, fn ->
      with {:ok, params} <- Proto.to_map(request),
           {:ok, project_id} <- Actions.get_project_id(params) do
        %{project_id: project_id, status: %{code: :OK}}
        |> Proto.deep_new!(GetProjectIdResponse)
      else
        {:error, {code, message}} ->
          %{status: %{code: code, message: to_str(message)}}
          |> Proto.deep_new!(GetProjectIdResponse)
      end
    end)
  end

  # Version

  def version(_, _stream) do
    version =
      :application.loaded_applications()
      |> Enum.find(fn {k, _, _} -> k == :scheduler end)
      |> elem(2)
      |> List.to_string()

    VersionResponse.new(version: version)
  end

  # Utility

  def date_time_to_timestamps(_field_name, nil), do: %{seconds: 0, nanos: 0}
  def date_time_to_timestamps(_fn, val = %{seconds: _s, nanos: _n}), do: val

  def date_time_to_timestamps(_fn, %{"seconds" => s, "nanos" => n}) do
    %{seconds: s, nanos: n}
  end

  def date_time_to_timestamps(_field_name, date_time = %DateTime{}) do
    %{}
    |> Map.put(:seconds, DateTime.to_unix(date_time, :second))
    |> Map.put(:nanos, elem(date_time.microsecond, 0) * 1_000)
  end

  def date_time_to_timestamps(_field_name, n_date_time = %NaiveDateTime{}) do
    {:ok, date_time} = DateTime.from_naive(n_date_time, "Etc/UTC")

    %{}
    |> Map.put(:seconds, DateTime.to_unix(date_time, :second))
    |> Map.put(:nanos, elem(date_time.microsecond, 0) * 1_000)
  end

  defp to_str(val) when is_binary(val), do: val
  defp to_str(val), do: "#{inspect(val)}"
end
