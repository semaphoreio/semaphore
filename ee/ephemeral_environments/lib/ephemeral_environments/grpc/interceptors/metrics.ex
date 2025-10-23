defmodule EphemeralEnvironments.Grpc.Interceptor.Metrics do
  @behaviour GRPC.ServerInterceptor
  require Logger

  def init(options) do
    options
  end

  def call(request, stream, next, _) do
    Logger.debug("Metrics intercepter #{inspect(request)}")
    next.(request, stream)
  end
end
