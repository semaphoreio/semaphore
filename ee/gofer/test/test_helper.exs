# gRPC mocks
GrpcMock.defmock(RepoHubMock, for: InternalApi.Repository.RepositoryService.Service)
GrpcMock.defmock(SecrethubMock, for: InternalApi.Secrethub.SecretService.Service)
GrpcMock.defmock(RBACMock, for: InternalApi.RBAC.RBAC.Service)

ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start(trace: true, capture_log: true, exclude: [:skip])
