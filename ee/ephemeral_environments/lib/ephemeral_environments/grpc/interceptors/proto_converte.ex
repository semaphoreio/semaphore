defmodule EphemeralEnvironments.Grpc.Interceptor.ProtoConverter do
  @behaviour GRPC.ServerInterceptor
  require Logger

  def init(options) do
    options
  end

  def call(request, stream, next, _) do
    Logger.debug("Proto intercepter - Request: #{inspect(request)}")
    converted_request = EphemeralEnvironments.Utils.Proto.to_map(request)
    {:ok, stream, response} = next.(converted_request, stream)

    converted_response = EphemeralEnvironments.Utils.Proto.from_map(response, stream.response_mod)
    Logger.debug("Proto intercepter - Response: #{inspect(converted_response)}")
    {:ok, stream, converted_response}
  end
end
