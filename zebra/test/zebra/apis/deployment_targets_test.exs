# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Zebra.Apis.DeploymentTargetsTest do
  use Zebra.DataCase

  @org_id Ecto.UUID.generate()
  @user_id Ecto.UUID.generate()
  @dt_id Ecto.UUID.generate()

  @authorized_projects [
    Ecto.UUID.generate()
  ]

  test "when job has no deployment_target_id then grant access" do
    mock_repo_proxy(:BRANCH, "master", "test-org/test-repo", "")

    {:ok, task} = Support.Factories.Task.create()

    {:ok, job} =
      Support.Factories.Job.create(:pending, %{
        project_id: hd(@authorized_projects),
        organization_id: @org_id,
        build_id: task.id
      })

    assert {:ok, true} = Zebra.Apis.DeploymentTargets.can_run?(job, @user_id)
  end

  test "when job has deployment_target_id then check positive access from gofer" do
    GrpcMock.stub(Support.FakeServers.DeploymentTargetsApi, :verify, fn _, _ ->
      InternalApi.Gofer.DeploymentTargets.VerifyResponse.new(
        status: InternalApi.Gofer.DeploymentTargets.VerifyResponse.Status.value(:ACCESS_GRANTED)
      )
    end)

    mock_repo_proxy(:BRANCH, "master", "test-org/test-repo", "")

    {:ok, task} = Support.Factories.Task.create()

    {:ok, job} =
      Support.Factories.Job.create(:pending, %{
        project_id: hd(@authorized_projects),
        organization_id: @org_id,
        build_id: task.id,
        deployment_target_id: @dt_id
      })

    assert {:ok, true} = Zebra.Apis.DeploymentTargets.can_run?(job, @user_id)
  end

  test "when job has deployment_target_id then check negative access from gofer" do
    GrpcMock.stub(Support.FakeServers.DeploymentTargetsApi, :verify, fn _, _ ->
      InternalApi.Gofer.DeploymentTargets.VerifyResponse.new(
        status: InternalApi.Gofer.DeploymentTargets.VerifyResponse.Status.value(:BANNED_SUBJECT)
      )
    end)

    mock_repo_proxy(:BRANCH, "master", "test-org/test-repo", "")

    {:ok, task} = Support.Factories.Task.create()

    {:ok, job} =
      Support.Factories.Job.create(:pending, %{
        project_id: hd(@authorized_projects),
        organization_id: @org_id,
        build_id: task.id,
        deployment_target_id: @dt_id
      })

    assert {:error, :permission_denied,
            "You are not allowed to access Deployment Target[#{@dt_id}]: BANNED_SUBJECT"} =
             Zebra.Apis.DeploymentTargets.can_run?(job, @user_id)
  end

  test "when job has deployment_target_id and error occurs then return it" do
    GrpcMock.stub(Support.FakeServers.DeploymentTargetsApi, :verify, fn _, _ ->
      raise GRPC.RPCError, status: GRPC.Status.internal(), message: "some message"
    end)

    mock_repo_proxy(:BRANCH, "master", "test-org/test-repo", "")

    {:ok, task} = Support.Factories.Task.create()

    {:ok, job} =
      Support.Factories.Job.create(:pending, %{
        project_id: hd(@authorized_projects),
        organization_id: @org_id,
        build_id: task.id,
        deployment_target_id: @dt_id
      })

    assert {:error, :internal, "Unable to verify access to deployment target #{@dt_id}"} =
             Zebra.Apis.DeploymentTargets.can_run?(job, @user_id)
  end

  # Utility functions
  def mock_repo_proxy(hook_type, branch_name, repo_slug, pr_slug) do
    GrpcMock.stub(Support.FakeServers.RepoProxyApi, :describe, fn _, _ ->
      status = InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))

      hook =
        InternalApi.RepoProxy.Hook.new(
          repo_slug: repo_slug,
          git_ref_type: InternalApi.RepoProxy.Hook.Type.value(hook_type),
          pr_slug: pr_slug,
          branch_name: branch_name
        )

      %InternalApi.RepoProxy.DescribeResponse{status: status, hook: hook}
    end)
  end
end
