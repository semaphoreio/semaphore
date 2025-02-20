defmodule RepositoryHub.Server.Endpoint do
  use GRPC.Endpoint

  alias RepositoryHub.Server.{
    RequestIdInterceptor,
    MetricsInterceptor,
    LoggerInterceptor,
    SentryInterceptor,
    HealthCheck
  }

  run(HealthCheck)

  run(RepositoryHub.Server,
    interceptors: [
      RequestIdInterceptor,
      {LoggerInterceptor, skip_logs_for: ~w(
         describe
         describe_many
         list
         get_file
         get_ssh_key
         list_accessible_repositories
         list_collaborators
         check_deploy_key
         check_webhook
         describe_remote_repository
       )},
      MetricsInterceptor,
      {SentryInterceptor,
       status_codes_to_capture: [
         GRPC.Status.ok(),
         GRPC.Status.cancelled(),
         GRPC.Status.unknown(),
         GRPC.Status.invalid_argument(),
         GRPC.Status.deadline_exceeded(),
         GRPC.Status.already_exists(),
         GRPC.Status.permission_denied(),
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

  Application.compile_env(:repository_hub, :grpc_stubs, [])
  |> case do
    [] ->
      nil

    stubs ->
      for stub <- stubs do
        run(stub,
          interceptors: [
            RequestIdInterceptor
          ]
        )
      end
  end
end
