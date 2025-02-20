defmodule Support.FakeServices do
  def init do
    GrpcMock.defmock(ArtifacthubMock, for: InternalApi.Artifacthub.ArtifactService.Service)
    GrpcMock.defmock(SecretMock, for: InternalApi.Secrethub.SecretService.Service)
    GrpcMock.defmock(GoferMock, for: InternalApi.Gofer.Switch.Service)

    GrpcMock.defmock(DeploymentsMock,
      for: InternalApi.Gofer.DeploymentTargets.DeploymentTargets.Service
    )

    GrpcMock.defmock(DashboardMock, for: InternalApi.Dashboardhub.DashboardsService.Service)
    GrpcMock.defmock(PipelineMock, for: InternalApi.Plumber.PipelineService.Service)
    GrpcMock.defmock(RepoProxyMock, for: InternalApi.RepoProxy.RepoProxyService.Service)
    GrpcMock.defmock(SchedulerMock, for: InternalApi.PeriodicScheduler.PeriodicService.Service)
    GrpcMock.defmock(WorkflowMock, for: InternalApi.PlumberWF.WorkflowService.Service)
    GrpcMock.defmock(SelfHostedMock, for: InternalApi.SelfHosted.SelfHostedAgents.Service)
    GrpcMock.defmock(JobMock, for: InternalApi.ServerFarm.Job.JobService.Service)
    GrpcMock.defmock(NotificationsMock, for: InternalApi.Notifications.NotificationsApi.Service)

    GrpcMock.defmock(ProjecthubMock, for: InternalApi.Projecthub.ProjectService.Service)
    GrpcMock.defmock(UserMock, for: InternalApi.User.UserService.Service)
    GrpcMock.defmock(OrganizationMock, for: InternalApi.Organization.OrganizationService.Service)
    GrpcMock.defmock(FeatureMock, for: InternalApi.Feature.FeatureService.Service)
    GrpcMock.defmock(RBACMock, for: InternalApi.RBAC.RBAC.Service)

    GrpcMock.defmock(PermissionPatrolMock,
      for: InternalApi.PermissionPatrol.PermissionPatrol.Service
    )

    services = [
      SecretMock,
      GoferMock,
      DeploymentsMock,
      DashboardMock,
      PipelineMock,
      RepoProxyMock,
      SchedulerMock,
      WorkflowMock,
      SelfHostedMock,
      NotificationsMock,
      JobMock,
      RBACMock,
      ProjecthubMock,
      UserMock,
      OrganizationMock,
      FeatureMock,
      PermissionPatrolMock
    ]

    spawn(fn ->
      GRPC.Server.start(services, 50_052)
    end)

    {:ok, _} = FunRegistry.start()
  end
end
