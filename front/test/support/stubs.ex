defmodule Support.Stubs do
  alias Support.Stubs

  def init do
    if initiated?() do
      do_reset()
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
    Support.Stubs.Dashboard.init()
    Support.Stubs.Secret.init()
    Support.Stubs.Project.init()
    Support.Stubs.Branch.init()
    Support.Stubs.Hook.init()
    Support.Stubs.Workflow.init()
    Support.Stubs.Pipeline.init()
    Support.Stubs.Task.init()
    Support.Stubs.Artifacthub.init()
    Support.Stubs.Repository.init()
    Support.Stubs.RepositoryIntegrator.init()
    Support.Stubs.Scheduler.init()
    Support.Stubs.SelfHostedAgent.init()
    Support.Stubs.Notification.init()
    Support.Stubs.Guard.init()
    Support.Stubs.Velocity.init()
    Support.Stubs.PreFlightChecks.init()
    Support.Stubs.AuditLog.init()
    Support.Stubs.Okta.init()
    Support.Stubs.Feature.init()
    Support.Stubs.RBAC.init()
    Support.Stubs.PermissionPatrol.init()
    Support.Stubs.Deployments.init()
    Support.Stubs.Billing.init()
    Support.Stubs.Scouter.init()
    Support.Stubs.InstanceConfig.init()
    Support.Stubs.Switch.init()
    Support.Stubs.Secrethub.init()

    :ok
  end

  defp do_reset do
    Support.Stubs.DB.reset()
    Support.Stubs.Time.reset()

    Support.Stubs.User.Grpc.init()
    Support.Stubs.Organization.Grpc.init()
    Support.Stubs.Dashboard.Grpc.init()
    Support.Stubs.Secret.Grpc.init()
    Support.Stubs.Project.Grpc.restart()
    Support.Stubs.Branch.Grpc.init()
    Support.Stubs.Hook.Grpc.init()
    Support.Stubs.Workflow.Grpc.init()
    Support.Stubs.Pipeline.Grpc.init()
    Support.Stubs.Task.Grpc.init()
    Support.Stubs.Task.Grpc.Job.init()
    Support.Stubs.Artifacthub.Grpc.init()
    Support.Stubs.Repository.init()
    Support.Stubs.Scheduler.Grpc.init()
    Support.Stubs.SelfHostedAgent.Grpc.init()
    Support.Stubs.Notification.Grpc.init()
    Support.Stubs.Guard.Grpc.init()
    Support.Stubs.Velocity.Grpc.init()
    Support.Stubs.PreFlightChecks.Grpc.init()
    Support.Stubs.AuditLog.Grpc.init()
    Support.Stubs.Feature.Grpc.init()
    Support.Stubs.Feature.seed()
    Support.Stubs.RBAC.Grpc.init()
    Support.Stubs.RBAC.seed_data()
    Support.Stubs.PermissionPatrol.Grpc.init()
    Support.Stubs.Billing.Grpc.init()
    Support.Stubs.Scouter.Grpc.init()
    Support.Stubs.InstanceConfig.Grpc.init()
    Support.Stubs.Switch.Grpc.init()
    Support.Stubs.Secrethub.Grpc.init()

    :ok
  end

  defp initiated? do
    Process.whereis(Support.Stubs.DB.State) != nil
  end

  def build_shared_factories do
    Support.Stubs.PermissionPatrol.allow_everything()
    Stubs.Feature.seed()

    user = Stubs.User.create_default()

    org =
      Stubs.Organization.create_default(owner_id: user.id)
      |> tap(fn %{id: org_id} ->
        Stubs.Feature.set_org_defaults(org_id)
      end)

    Support.Stubs.RBAC.add_owner(org.id, user.id)

    project =
      Stubs.Project.create(org, user,
        run_on: ["branches"],
        state: InternalApi.Projecthub.Project.Status.State.value(:READY)
      )

    branch = Stubs.Branch.create(project)

    hook = Stubs.Hook.create(branch)
    workflow = Stubs.Workflow.create(hook, user)

    pipeline =
      Stubs.Pipeline.create_initial(workflow, name: "Build & Test", organization_id: org.id)

    switch = Stubs.Pipeline.add_switch(pipeline)
    block1 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 1"})
    Stubs.Switch.add_target(switch)
    Stubs.Switch.add_target(switch, name: "staging")

    Stubs.Secret.create_default()
    Stubs.Notification.create_default(org)
    Stubs.Dashboard.create(org)

    Stubs.Project.add_member(project.id, user.id)

    # Add project artifacts

    project
    |> Stubs.Project.add_artifact(
      path: "dir/subdir/README.md",
      url: "http://some/path/dir/subdir/README.md"
    )

    project
    |> Stubs.Project.add_artifact(
      path: "dir/subdir/testdir/some_file",
      url: "http://some/path/dir/subdir/testdir/some_file"
    )

    # Add workflow artifacts

    workflow
    |> Stubs.Workflow.add_artifact(
      path: "dir/subdir/README.md",
      url: "http://some/path/dir/subdir/README.md"
    )

    workflow
    |> Stubs.Workflow.add_artifact(
      path: "dir/subdir/testdir/some_file",
      url: "http://some/path/dir/subdir/testdir/some_file"
    )

    # Add pipeline artifacts

    pipeline
    |> Stubs.Pipeline.add_artifact(
      path: "dir/subdir/README.md",
      url: "http://some/path/dir/subdir/README.md"
    )

    pipeline
    |> Stubs.Pipeline.add_artifact(
      path: "dir/subdir/testdir/some_file",
      url: "http://some/path/dir/subdir/testdir/some_file"
    )

    # Add job artifacts
    %{api_model: %{jobs: jobs}} = Stubs.Task.create(block1)

    jobs
    |> Enum.each(fn job ->
      job
      |> Stubs.Task.add_job_artifact(
        path: "dir/subdir/README.md",
        url: "http://some/path/dir/subdir/README.md"
      )

      job
      |> Stubs.Task.add_job_artifact(
        path: "dir/subdir/testdir/some_file",
        url: "http://some/path/dir/subdir/testdir/some_file"
      )
    end)
  end
end
