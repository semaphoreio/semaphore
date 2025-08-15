GrpcMock.defmock(SecretMock, for: InternalApi.Secrethub.SecretService.Service)
GrpcMock.defmock(RBACMock, for: InternalApi.RBAC.RBAC.Service)
GrpcMock.defmock(PipelinesMock, for: InternalApi.Plumber.PipelineService.Service)
GrpcMock.defmock(ProjectServiceMock, for: InternalApi.Projecthub.ProjectService.Service)
GrpcMock.defmock(RepoProxyMock, for: InternalApi.RepoProxy.RepoProxyService.Service)
GrpcMock.defmock(WorkflowMock, for: InternalApi.PlumberWF.WorkflowService.Service)
GrpcMock.defmock(OrganizationMock, for: InternalApi.Organization.OrganizationService.Service)

spawn(fn ->
  GRPC.Server.start(
    [
      SecretMock,
      RBACMock,
      PipelinesMock,
      ProjectServiceMock,
      RepoProxyMock,
      WorkflowMock,
      OrganizationMock
    ],
    50_052
  )
end)

formatters = [ExUnit.CLIFormatter, JUnitFormatter]

ExUnit.configure(formatters: formatters)
ExUnit.start(trace: false, capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Notifications.Repo, :manual)
