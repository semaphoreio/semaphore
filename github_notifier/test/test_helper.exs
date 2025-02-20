ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start(capture_log: true)

GrpcMock.defmock(PipelineMock, for: InternalApi.Plumber.PipelineService.Service)
GrpcMock.defmock(UserMock, for: InternalApi.User.UserService.Service)
GrpcMock.defmock(ProjecthubMock, for: InternalApi.Projecthub.ProjectService.Service)
GrpcMock.defmock(OrganizationMock, for: InternalApi.Organization.OrganizationService.Service)
GrpcMock.defmock(RepoProxyMock, for: InternalApi.RepoProxy.RepoProxyService.Service)
GrpcMock.defmock(RepositoryHubMock, for: InternalApi.Repository.RepositoryService.Service)
GrpcMock.defmock(VelocityHubMock, for: InternalApi.Velocity.PipelineMetricsService.Service)
GrpcMock.defmock(FeatureMock, for: InternalApi.Feature.FeatureService.Service)

GrpcMock.defmock(RepositoryIntegratorMock,
  for: InternalApi.RepositoryIntegrator.RepositoryIntegratorService.Service
)

services = [
  PipelineMock,
  UserMock,
  ProjecthubMock,
  OrganizationMock,
  RepoProxyMock,
  RepositoryIntegratorMock,
  RepositoryHubMock,
  VelocityHubMock,
  FeatureMock
]

{:ok, _, _} = GRPC.Server.start(services, 50_052)
