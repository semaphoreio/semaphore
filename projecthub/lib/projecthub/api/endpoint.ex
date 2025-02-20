defmodule Projecthub.Api.Endpoint do
  use GRPC.Endpoint

  alias Projecthub.Util.GRPC.{
    ServerLoggerInterceptor,
    ServerRequestIdInterceptor,
    ServerMetricsInterceptor
  }

  run(Projecthub.Api.HealthCheck)

  run(Projecthub.Api.GrpcServer,
    interceptors: [
      ServerRequestIdInterceptor,
      {
        ServerLoggerInterceptor,
        skip_logs_for: ~w(
          describe
          describe_many
          list
          list_projects
          users
          check_deploy_key
          check_webhook
        )
      },
      {ServerMetricsInterceptor, "projecthub"}
    ]
  )

  Application.get_env(:projecthub, :grpc_stubs, [])
  |> case do
    [] ->
      nil

    stubs ->
      for stub <- stubs do
        run(stub,
          interceptors: [ServerRequestIdInterceptor, ServerLoggerInterceptor]
        )
      end
  end
end
