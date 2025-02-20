defmodule HooksProcessor.Clients.BranchClient do
  @moduledoc """
  Module is used for communication with Branch service over gRPC.
  """

  alias InternalApi.Branch.{BranchService, FindOrCreateRequest, DescribeRequest, ArchiveRequest}
  alias Util.{Metrics, ToTuple}
  alias LogTee, as: LT

  defp url, do: Application.get_env(:hooks_processor, :branch_api_grpc_url)

  @wormhole_timeout 6_000
  @grpc_timeout 5_000

  # FindOrCreate

  def find_or_create(hook, parsed_data) do
    "project_id: #{hook.project_id} and branch_name: #{parsed_data.branch_name}"
    |> LT.info("Hook #{hook.id} - calling Branch API to find or create branch")

    Metrics.benchmark("HooksProcessor.BranchClient", ["find_or_create"], fn ->
      %FindOrCreateRequest{
        project_id: hook.project_id,
        repository_id: hook.repository_id,
        name: parsed_data.branch_name,
        display_name: parsed_data.display_name,
        ref_type: ref_type(parsed_data.branch_name),
        pr_name: parsed_data.pr_name,
        pr_number: parsed_data.pr_number
      }
      |> do_find_or_create()
    end)
  end

  defp ref_type("refs/tags/" <> _rest), do: :TAG
  defp ref_type("pull-request-" <> __rest), do: :PR
  defp ref_type(_branch_name), do: :BRANCH

  defp do_find_or_create(request) do
    result =
      Wormhole.capture(__MODULE__, :find_or_create_grpc, [request],
        stacktrace: true,
        timeout: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def find_or_create_grpc(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    channel
    |> BranchService.Stub.find_or_create(request, timeout: @grpc_timeout)
    |> process_find_or_create_status()
  end

  defp process_find_or_create_status({:ok, map}) do
    case map |> Map.get(:status, %{}) |> Map.get(:code) do
      :OK ->
        map |> Map.get(:branch) |> ToTuple.ok()

      :BAD_PARAM ->
        map |> Map.get(:status, %{}) |> Map.get(:message) |> ToTuple.error()

      _ ->
        log_invalid_response(map, "find_or_create")
    end
  end

  defp process_find_or_create_status(error = {:error, _msg}), do: error
  defp process_find_or_create_status(error), do: {:error, error}

  # Describe

  def describe(hook, parsed_data) do
    params = [hook.project_id, parsed_data.branch_name]

    "project_id: #{Enum.at(params, 0)} and branch_name: #{Enum.at(params, 1)}"
    |> LT.info("Hook #{hook.id} - fetching details from Branch API for branch")

    result =
      Wormhole.capture(__MODULE__, :describe_grpc, params,
        stacktrace: true,
        timeout: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def describe_grpc(project_id, branch_name) do
    Metrics.benchmark("HooksProcessor.BranchClient.describe", fn ->
      request = %DescribeRequest{project_id: project_id, branch_name: branch_name}
      {:ok, channel} = GRPC.Stub.connect(url())

      channel
      |> BranchService.Stub.describe(request, timeout: @grpc_timeout)
      |> process_describe_status()
    end)
  end

  defp process_describe_status({:ok, map}) do
    case map |> Map.get(:status, %{}) |> Map.get(:code) do
      :OK ->
        map |> Map.get(:branch) |> ToTuple.ok()

      :BAD_PARAM ->
        map |> Map.get(:status, %{}) |> Map.get(:message) |> ToTuple.error()

      _ ->
        log_invalid_response(map, "describe")
    end
  end

  defp process_describe_status(error = {:error, _msg}), do: error
  defp process_describe_status(error), do: {:error, error}

  # Archive

  def archive(branch_id, hook) do
    LT.info(branch_id, "Hook #{hook.id} - calling Branch API to archive branch")

    %ArchiveRequest{branch_id: branch_id, requested_at: datetime_to_timestamp(hook.received_at)}
    |> do_archive()
  end

  def datetime_to_timestamp(nil), do: %{seconds: 0, nanos: 0}

  def datetime_to_timestamp(datetime = %DateTime{}) do
    %{}
    |> Map.put(:seconds, DateTime.to_unix(datetime, :second))
    |> Map.put(:nanos, elem(datetime.microsecond, 0) * 1_000)
  end

  def date_time_to_timestamps(_field_name, value), do: value

  defp do_archive(request) do
    result =
      Wormhole.capture(__MODULE__, :archive_grpc, [request],
        stacktrace: true,
        timeout: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def archive_grpc(request) do
    Metrics.benchmark("HooksProcessor.BranchClient.archive", fn ->
      {:ok, channel} = GRPC.Stub.connect(url())

      channel
      |> BranchService.Stub.archive(request, timeout: @grpc_timeout)
      |> process_archive_status()
    end)
  end

  defp process_archive_status({:ok, map}) do
    map
    |> Map.get(:status)
    |> case do
      %{code: :OK} ->
        ToTuple.ok("Branch successfully archived.")

      %{code: :BAD_PARAM, message: message} ->
        ToTuple.error(message)

      _ ->
        log_invalid_response(map, "archive")
    end
  end

  defp process_archive_status(error = {:error, _msg}), do: error
  defp process_archive_status(error), do: {:error, error}

  # Utility

  defp log_invalid_response(response, method) do
    response
    |> LT.error("Branch Service responded to #{method} with :ok and invalid data:")
    |> ToTuple.error()
  end
end
