Code.require_file("test/support/grpc_server_helper.ex")

formatters = [ExUnit.CLIFormatter]

formatters =
  System.get_env("CI", "")
  |> case do
    "" ->
      formatters

    _ ->
      [JUnitFormatter | formatters]
  end
ExUnit.configure(
  exclude: [integration: true],
  capture_log: true,
  formatters: formatters
)
ExUnit.start()

defmodule Test.MockGoferService do
  use GRPC.Server, service: InternalApi.Gofer.Switch.Service

  alias InternalApi.Gofer.ResponseStatus.ResponseCode
  alias InternalApi.Gofer.{ResponseStatus, CreateResponse, PipelineDoneResponse}

  def create(_create_request, _stream) do
    response_type = Application.get_env(:gofer_client, :test_gofer_service_response)
    respond(response_type, :create)
  end

  def pipeline_done(_request, _stream) do
    response_type = Application.get_env(:gofer_client, :test_gofer_service_response)
    respond(response_type, :pipeline_done)
  end

  # Create
  defp respond("valid", :create) do
    %{response_status: ResponseStatus.new(code: ResponseCode.value(:OK), message: "")}
    |> Map.merge(%{switch_id: UUID.uuid4()})
    |> CreateResponse.new()
  end
  defp respond("bad_param", :create) do
    %{response_status: ResponseStatus.new(code: ResponseCode.value(:BAD_PARAM), message: "Error")}
    |> Map.merge(%{switch_id: ""})
    |> CreateResponse.new()
  end
  defp respond("malformed", :create) do
    %{response_status: ResponseStatus.new(code: ResponseCode.value(:MALFORMED),
                                          message: "Malformed error")}
    |> Map.merge(%{switch_id: ""})
    |> CreateResponse.new()
  end
  defp respond("timeout", rpc_method) do
    :timer.sleep(5_000)
    response(rpc_method)
  end
  # PipelineDone
  defp respond("valid", :pipeline_done) do
    %{response_status: ResponseStatus.new(code: ResponseCode.value(:OK), message: "Valid message")}
    |> PipelineDoneResponse.new()
  end
  defp respond(response_type, :pipeline_done) do
    code = response_type |> String.upcase() |> String.to_atom() |> ResponseCode.value()
    message = response_type |> String.upcase()
    %{response_status: ResponseStatus.new(code: code, message: message)}
    |> PipelineDoneResponse.new()
  end

  defp response(:create), do: CreateResponse.new()
  defp response(:pipeline_done), do: PipelineDoneResponse.new()
end
