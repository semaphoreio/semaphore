GrpcMock.defmock(RepositoryMock, for: InternalApi.Repository.RepositoryService.Service)

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
