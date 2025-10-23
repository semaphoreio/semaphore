defmodule EphemeralEnvironments.Grpc.Endpoint do
  use GRPC.Endpoint

  run(EphemeralEnvironments.Grpc.EphemeralEnvironmentsServer,
    interceptors: [
      EphemeralEnvironments.Grpc.Interceptor.Metrics,
      EphemeralEnvironments.Grpc.Interceptor.ProtoConverter
    ]
  )
end
