GrpcMock.defmock(Support.FakeServers.RBAC, for: InternalApi.RBAC.RBAC.Service)

GrpcMock.defmock(Support.FakeServers.ProjecthubApi,
  for: InternalApi.Projecthub.ProjectService.Service
)

GrpcMock.defmock(Support.FakeServers.OrganizationApi,
  for: InternalApi.Organization.OrganizationService.Service
)

GrpcMock.defmock(Support.FakeServers.SecretsApi, for: InternalApi.Secrethub.SecretService.Service)

GrpcMock.defmock(Support.FakeServers.ArtifactApi,
  for: InternalApi.Artifacthub.ArtifactService.Service
)

GrpcMock.defmock(Support.FakeServers.CacheApi, for: InternalApi.Cache.CacheService.Service)
GrpcMock.defmock(Support.FakeServers.ChmuraApi, for: InternalApi.Chmura.Chmura.Service)

GrpcMock.defmock(Support.FakeServers.RepoProxyApi,
  for: InternalApi.RepoProxy.RepoProxyService.Service
)

GrpcMock.defmock(Support.FakeServers.Loghub2Api, for: InternalApi.Loghub2.Loghub2.Service)

GrpcMock.defmock(Support.FakeServers.SelfHosted,
  for: InternalApi.SelfHosted.SelfHostedAgents.Service
)

GrpcMock.defmock(Support.FakeServers.RepositoryApi,
  for: InternalApi.Repository.RepositoryService.Service
)

GrpcMock.defmock(Support.FakeServers.DeploymentTargetsApi,
  for: InternalApi.Gofer.DeploymentTargets.DeploymentTargets.Service
)
