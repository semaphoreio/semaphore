{:ok, _} = FunRegistry.start()

GRPC.Server.start(
  [
    Support.FakeServices.ProjectService,
    Support.FakeServices.OrganizationService,
    Support.FakeServices.RbacService
  ],
  50_051
)

ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start(trace: true)
