defmodule HooksProcessor.Hooks.Grpc.Endpoint do
  use GRPC.Endpoint

  alias HooksProcessor.Hooks.Grpc.{
    SentryInterceptor,
    HealthCheck,
    Server
  }

  run(HealthCheck)

  run(Server,
    interceptors: [
      {SentryInterceptor,
       status_codes_to_capture: [
         GRPC.Status.ok(),
         GRPC.Status.cancelled(),
         GRPC.Status.unknown(),
         GRPC.Status.invalid_argument(),
         GRPC.Status.deadline_exceeded(),
         GRPC.Status.already_exists(),
         GRPC.Status.permission_denied(),
         GRPC.Status.resource_exhausted(),
         GRPC.Status.aborted(),
         GRPC.Status.out_of_range(),
         GRPC.Status.unimplemented(),
         GRPC.Status.internal(),
         GRPC.Status.unavailable(),
         GRPC.Status.data_loss(),
         GRPC.Status.unauthenticated()
       ]}
    ]
  )
end
