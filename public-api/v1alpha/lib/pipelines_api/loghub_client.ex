defmodule PipelinesAPI.LoghubClient do
  @moduledoc """
  Module is used for fetching logs for cloud jobs from loghub
  """

  require Logger
  alias PipelinesAPI.Util.{Metrics, ToTuple}
  alias InternalApi.Loghub.GetLogEventsRequest
  alias LogTee, as: LT

  defp url(), do: System.get_env("LOGHUB_API_URL")

  @wormhole_timeout Application.compile_env(:pipelines_api, :grpc_timeout, [])

  def get_log_events(job_id) do
    Metrics.benchmark(__MODULE__, ["get_log_events"], fn ->
      form_get_log_events_request(job_id)
      |> grpc_call()
    end)
  end

  def form_get_log_events_request(job_id) do
    GetLogEventsRequest.new(job_id: job_id)
    |> ToTuple.ok()
  catch
    error -> error
  end

  defp grpc_call({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :do_get_log_events, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout,
        ok_tuple: true
      )

    case result do
      {:ok, result} ->
        process_get_log_events_response(result)

      {:error, reason} ->
        reason |> LT.error("loghub service responded with")
        ToTuple.internal_error("Internal error")
    end
  end

  defp grpc_call(error), do: error

  def do_get_log_events(request) do
    {:ok, channel} = url() |> GRPC.Stub.connect()

    InternalApi.Loghub.Loghub.Stub.get_log_events(channel, request, timeout: @wormhole_timeout)
  end

  def process_get_log_events_response(response) do
    if response.status.code == InternalApi.ResponseStatus.Code.value(:OK) do
      {:ok, response.events}
    else
      Logger.error("Error getting log events: #{inspect(response.status)}")
      ToTuple.internal_error("Internal error")
    end
  end
end
