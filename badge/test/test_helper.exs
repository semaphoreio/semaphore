GrpcMock.defmock(ProjectMock, for: InternalApi.Projecthub.ProjectService.Service)
GrpcMock.defmock(PipelineMock, for: InternalApi.Plumber.PipelineService.Service)

GRPC.Server.start([ProjectMock, PipelineMock], 50_052)

Cachex.reset(:badges_cache)

ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start(trace: true)
