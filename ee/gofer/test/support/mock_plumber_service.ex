defmodule Test.MockPlumberService do
  use GRPC.Server, service: InternalApi.Plumber.PipelineService.Service

  alias Google.Protobuf.Timestamp
  alias InternalApi.Plumber.ResponseStatus.ResponseCode
  alias InternalApi.Plumber.Pipeline.{State, Result, ResultReason}

  alias InternalApi.Plumber.{
    ResponseStatus,
    ScheduleExtensionResponse,
    DescribeResponse,
    Pipeline
  }

  def describe(_request, _stream) do
    response_type = Application.get_env(:gofer, :test_plumber_service_describe_response)
    describe_response(response_type)
  end

  defp describe_response("running") do
    %{response_status: ResponseStatus.new(code: ResponseCode.value(:OK), message: "")}
    |> Map.merge(%{pipeline: Pipeline.new(%{state: st_code("running"), result: code("passed")})})
    |> DescribeResponse.new()
  end

  defp describe_response("passed") do
    now = DateTime.utc_now() |> DateTime.to_unix()

    %{response_status: ResponseStatus.new(code: ResponseCode.value(:OK), message: "")}
    |> Map.merge(%{
      pipeline:
        Pipeline.new(%{
          state: st_code("done"),
          result: code("passed"),
          done_at: Timestamp.new(%{seconds: now})
        })
    })
    |> DescribeResponse.new()
  end

  defp describe_response("failed") do
    now = DateTime.utc_now() |> DateTime.to_unix()

    %{response_status: ResponseStatus.new(code: :OK, message: "")}
    |> Map.merge(%{
      pipeline:
        Pipeline.new(%{
          state: st_code("done"),
          result: code("failed"),
          done_at: Timestamp.new(%{seconds: now}),
          result_reason: rr_code("test")
        })
    })
    |> DescribeResponse.new()
  end

  defp describe_response("bad_param") do
    %{response_status: ResponseStatus.new(code: :BAD_PARAM, message: "Error")}
    |> DescribeResponse.new()
  end

  defp describe_response("limit_exceeded") do
    %{
      response_status:
        ResponseStatus.new(code: ResponseCode.value(:LIMIT_EXCEEDED), message: "Error")
    }
    |> DescribeResponse.new()
  end

  defp describe_response("timeout") do
    :timer.sleep(5_000)
    DescribeResponse.new()
  end

  defp st_code(result) do
    result |> String.upcase() |> String.to_atom() |> State.value()
  end

  defp code(result) do
    result |> String.upcase() |> String.to_atom() |> Result.value()
  end

  defp rr_code(result) do
    result |> String.upcase() |> String.to_atom() |> ResultReason.value()
  end

  def schedule_extension(_request, _stream) do
    response_type = Application.get_env(:gofer, :test_plumber_service_schedule_response)
    schedule_response(response_type)
  end

  defp schedule_response("valid") do
    %{response_status: ResponseStatus.new(code: ResponseCode.value(:OK), message: "")}
    |> Map.merge(%{ppl_id: UUID.uuid4()})
    |> ScheduleExtensionResponse.new()
  end

  defp schedule_response("bad_param") do
    %{response_status: ResponseStatus.new(code: ResponseCode.value(:BAD_PARAM), message: "Error")}
    |> Map.merge(%{ppl_id: ""})
    |> ScheduleExtensionResponse.new()
  end

  defp schedule_response("timeout") do
    :timer.sleep(5_000)
    ScheduleExtensionResponse.new()
  end
end
