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
    GrpcMock.defmock(GuardMock, for: InternalApi.Guard.Guard.Service)
    GrpcMock.defmock(OrganizationMock, for: InternalApi.Organization.OrganizationService.Service)
    GrpcMock.defmock(BillingMock, for: InternalApi.Billing.BillingService.Service)
    GrpcMock.defmock(FeatureMock, for: InternalApi.Feature.FeatureService.Service)
    GrpcMock.defmock(RBACMock, for: InternalApi.RBAC.RBAC.Service)
    GrpcMock.defmock(LoghubMock, for: InternalApi.Loghub.Loghub.Service)
    GrpcMock.defmock(Loghub2Mock, for: InternalApi.Loghub2.Loghub2.Service)
    GrpcMock.defmock(SuperjerryMock, for: InternalApi.Superjerry.Superjerry.Service)
    GrpcMock.defmock(VelocityMock, for: InternalApi.Velocity.PipelineMetricsService.Service)

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
      GuardMock,
      OrganizationMock,
      BillingMock,
      FeatureMock,
      RBACMock,
      LoghubMock,
      Loghub2Mock,
      SuperjerryMock,
      VelocityMock
    ]

    spawn(fn ->
      GRPC.Server.start(services, 50_052)
    end)

    {:ok, _} = FunRegistry.start()
  end
end
