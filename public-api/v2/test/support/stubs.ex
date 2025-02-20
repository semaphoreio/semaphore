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
    Support.Stubs.Notifications.init()
    Support.Stubs.Deployments.init()
    Support.Stubs.Dashboards.init()
    Support.Stubs.Job.init()
    Support.Stubs.RepoProxy.init()
    Support.Stubs.Feature.init()
    Support.Stubs.PermissionPatrol.init()
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
    Support.Stubs.Notifications.Grpc.init()
    Support.Stubs.Deployments.Grpc.init()
    Support.Stubs.Dashboards.Grpc.init()
    Support.Stubs.Job.Grpc.init()
    Support.Stubs.RepoProxy.Grpc.init()
    Support.Stubs.Feature.Grpc.init()
    Support.Stubs.Feature.seed()
    Support.Stubs.PermissionPatrol.Grpc.init()
    Support.Stubs.RBAC.Grpc.init()
    Support.Stubs.RBAC.seed_data()

    :ok
  end

  defp initiated? do
    Process.whereis(Support.Stubs.DB.State) != nil
  end

  def build_shared_factories do
    user = Support.Stubs.User.create_default()

    Support.Stubs.Organization.create_default(owner_id: user.id)

    Support.Stubs.Feature.seed()
  end
end
