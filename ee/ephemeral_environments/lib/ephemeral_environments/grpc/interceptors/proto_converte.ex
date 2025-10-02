defmodule EphemeralEnvironments.Grpc.Interceptor.ProtoConverter do
  @behaviour GRPC.ServerInterceptor
  require Logger

  def init(options) do
    options
  end

  def call(request, stream, next, _) do
    Logger.debug("Proto intercepter #{inspect(request)}")
    converted = EphemeralEnvironments.Utils.Proto.to_map(request)
    next.(converted, stream)
  end
end
