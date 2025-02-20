defmodule Support.FakeServices do
  def init do
    GrpcMock.defmock(ArtifacthubMock, for: InternalApi.Artifacthub.ArtifactService.Service)
    GrpcMock.defmock(SecretMock, for: InternalApi.Secrethub.SecretService.Service)
    GrpcMock.defmock(GoferMock, for: InternalApi.Gofer.Switch.Service)

    GrpcMock.defmock(DeploymentsMock,
      for: InternalApi.Gofer.DeploymentTargets.DeploymentTargets.Service
    )

    GrpcMock.defmock(PipelineMock, for: InternalApi.Plumber.PipelineService.Service)
    GrpcMock.defmock(RepoProxyMock, for: InternalApi.RepoProxy.RepoProxyService.Service)
    GrpcMock.defmock(SchedulerMock, for: InternalApi.PeriodicScheduler.PeriodicService.Service)
    GrpcMock.defmock(WorkflowMock, for: InternalApi.PlumberWF.WorkflowService.Service)
    GrpcMock.defmock(SelfHostedMock, for: InternalApi.SelfHosted.SelfHostedAgents.Service)
    GrpcMock.defmock(JobMock, for: InternalApi.ServerFarm.Job.JobService.Service)

    GrpcMock.defmock(ProjectMock, for: InternalApi.Projecthub.ProjectService.Service)
    GrpcMock.defmock(UserMock, for: InternalApi.User.UserService.Service)
    GrpcMock.defmock(OrganizationMock, for: InternalApi.Organization.OrganizationService.Service)
    GrpcMock.defmock(FeatureMock, for: InternalApi.Feature.FeatureService.Service)
    GrpcMock.defmock(RBACMock, for: InternalApi.RBAC.RBAC.Service)
    GrpcMock.defmock(LoghubMock, for: InternalApi.Loghub.Loghub.Service)
    GrpcMock.defmock(Loghub2Mock, for: InternalApi.Loghub2.Loghub2.Service)

    services = [
      ArtifacthubMock,
      SecretMock,
      GoferMock,
      DeploymentsMock,
      PipelineMock,
      RepoProxyMock,
      SchedulerMock,
      WorkflowMock,
      SelfHostedMock,
      JobMock,
      ProjectMock,
      UserMock,
      OrganizationMock,
      FeatureMock,
      RBACMock,
      LoghubMock,
      Loghub2Mock
    ]

    spawn(fn ->
      GRPC.Server.start(services, 50_052)
    end)

    {:ok, _} = FunRegistry.start()
  end
end
