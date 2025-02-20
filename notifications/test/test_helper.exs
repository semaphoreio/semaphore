GrpcMock.defmock(SecretMock, for: InternalApi.Secrethub.SecretService.Service)
GrpcMock.defmock(RBACMock, for: InternalApi.RBAC.RBAC.Service)

spawn(fn ->
  GRPC.Server.start([SecretMock, RBACMock], 50_052)
end)

formatters = [ExUnit.CLIFormatter, JUnitFormatter]

ExUnit.configure(formatters: formatters)
ExUnit.start(trace: false, capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Notifications.Repo, :manual)
