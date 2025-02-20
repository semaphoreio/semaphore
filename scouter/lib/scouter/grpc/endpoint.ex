defmodule Scouter.GRPC.Endpoint do
  @moduledoc """
  This module is responsible for defining the GRPC endpoint for the Scouter service.
  """

  use GRPC.Endpoint

  run(Scouter.GRPC.HealthCheck)

  intercept(GRPC.Server.Interceptors.Logger)

  run(Scouter.GRPC.Server,
    interceptors: Scouter.GRPC.MetricsInterceptor
  )
end
