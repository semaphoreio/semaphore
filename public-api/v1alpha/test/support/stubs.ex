defmodule Support.Stubs do
  def init do
    if initiated?() do
      reset()
    else
      do_init()
    end
  end

  defp do_init do
    Support.FakeServices.init()

    Support.Stubs.Time.init()
    Support.Stubs.DB.init()

    Support.Stubs.User.init()
    Support.Stubs.Organization.init()
    Support.Stubs.Secret.init()
    Support.Stubs.Branch.init()
    Support.Stubs.Hook.init()
    Support.Stubs.Project.init()
    Support.Stubs.Workflow.init()
    Support.Stubs.Pipeline.init()
    Support.Stubs.Switch.init()
    Support.Stubs.Artifacthub.init()
    Support.Stubs.Scheduler.init()
    Support.Stubs.SelfHostedAgent.init()
    Support.Stubs.Deployments.init()
    Support.Stubs.Job.init()
    Support.Stubs.RepoProxy.init()
    Support.Stubs.Feature.init()
    Support.Stubs.RBAC.init()

    :ok
  end

  def reset do
    Support.Stubs.DB.reset()
    Support.Stubs.Time.reset()
    Support.Stubs.User.Grpc.init()
    Support.Stubs.Organization.Grpc.init()
    Support.Stubs.Secret.Grpc.init()
    Support.Stubs.Project.Grpc.restart()
    Support.Stubs.Workflow.Grpc.init()
    Support.Stubs.Pipeline.Grpc.init()
    Support.Stubs.Switch.Grpc.init()
    Support.Stubs.Artifacthub.Grpc.init()
    Support.Stubs.Scheduler.Grpc.init()
    Support.Stubs.SelfHostedAgent.Grpc.init()
    Support.Stubs.Deployments.Grpc.init()
    Support.Stubs.Job.Grpc.init()
    Support.Stubs.RepoProxy.Grpc.init()
    Support.Stubs.Feature.Grpc.init()
    Support.Stubs.Feature.seed()
    Support.Stubs.RBAC.Grpc.init()
    Support.Stubs.RBAC.seed_data()

    :ok
  end

  defp initiated? do
    Process.whereis(Support.Stubs.DB.State) != nil
  end

  def grant_all_permissions do
    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(permissions: all_permissions())
    end)
  end

  def all_permissions do
    [
      "project.view",
      "project.job.rerun",
      "project.job.stop",
      "organization.self_hosted_agents.manage",
      "organization.self_hosted_agents.view",
      "project.general_settings.view",
      "project.general_settings.manage",
      "project.scheduler.manage",
      "project.scheduler.run_manually",
      "project.scheduler.view",
      "project.deployment_targets.view",
      "project.deployment_targets.manage"
    ]
  end

  def all_permissions_except(permission) do
    all_permissions()
    |> Enum.filter(fn p -> p != permission end)
  end

  def build_shared_factories do
    user = Support.Stubs.User.create_default()

    Support.Stubs.Organization.create_default(owner_id: user.id)
    |> tap(fn %{id: org_id} ->
      Support.Stubs.Feature.set_org_defaults(org_id)
    end)

    Support.Stubs.Feature.seed()
  end
end
