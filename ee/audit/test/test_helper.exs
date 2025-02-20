GrpcMock.defmock(UserMock, for: InternalApi.User.UserService.Service)
GrpcMock.defmock(FeatureMock, for: InternalApi.Feature.FeatureService.Service)

spawn_link(fn -> GRPC.Server.start([UserMock, FeatureMock], 50_052) end)

:timer.sleep(2000)

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
  exclude: [disabled: true],
  trace: true,
  capture_log: true,
  formatters: formatters
)

ExUnit.start()
