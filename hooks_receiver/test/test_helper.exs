GrpcMock.defmock(RepositoryMock, for: InternalApi.Repository.RepositoryService.Service)
GrpcMock.defmock(LicenseMock, for: InternalApi.License.LicenseService.Service)

GRPC.Server.start([RepositoryMock, LicenseMock], 50_051)

formatters = [ExUnit.CLIFormatter]

formatters =
  System.get_env("CI", "")
  |> case do
    "" ->
      formatters

    _ ->
      [JUnitFormatter | formatters]
  end

ExUnit.configure(formatters: formatters)
ExUnit.start(trace: true, capture_log: true)
