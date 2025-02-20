defmodule HooksProcessor.Hooks.Api.Server.Test do
  use ExUnit.Case, async: false

  alias HooksProcessor.Hooks.Model.HooksQueries
  alias InternalApi.RepoProxy.CreateBlankRequest

  alias InternalApi.RepoProxy.{
    RepoProxyService,
    CreateRequest
  }

  alias InternalApi.{
    Projecthub,
    Branch,
    Repository,
    User,
    PlumberWF
  }

  @grpc_port 50_044

  setup_all do
    mocks = [UserServiceMock, ProjectHubServiceMock, RepositoryServiceMock, BranchServiceMock, WorkflowServiceMock]
    GRPC.Server.start(mocks, @grpc_port)

    Application.put_env(:hooks_processor, :projecthub_grpc_url, "localhost:#{inspect(@grpc_port)}")
    Application.put_env(:hooks_processor, :branch_api_grpc_url, "localhost:#{inspect(@grpc_port)}")
    Application.put_env(:hooks_processor, :plumber_grpc_url, "localhost:#{inspect(@grpc_port)}")
    Application.put_env(:hooks_processor, :repository_grpc_url, "localhost:#{inspect(@grpc_port)}")
    Application.put_env(:hooks_processor, :user_api_grpc_url, "localhost:#{inspect(@grpc_port)}")

    on_exit(fn ->
      GRPC.Server.stop(mocks)

      Test.Helpers.wait_until_stopped(mocks)
    end)

    {:ok,
     %{
       ppl_id: UUID.uuid4(),
       wf_id: UUID.uuid4(),
       branch_id: UUID.uuid4(),
       repository_id: UUID.uuid4(),
       project_id: UUID.uuid4(),
       requester_id: UUID.uuid4()
     }}
  end

  setup do
    Test.Helpers.truncate_db()

    :ok
  end

  # CreateRequest

  test "create() with proper params creates the workflow on plumber", ctx do
    ctx = Map.put(ctx, :integration_type, :BITBUCKET)

    mock_projecthub(ctx)
    mock_repositoryhub(ctx)
    mock_user_service(ctx)
    mock_branch_service(ctx)
    mock_workflow_service(ctx)

    request = %CreateRequest{
      project_id: ctx.project_id,
      requester_id: ctx.requester_id,
      triggered_by: :API,
      git: %{commit_sha: "", reference: "refs/heads/master"}
    }

    assert {:ok, channel} = GRPC.Stub.connect("localhost:50050")
    assert {:ok, response} = channel |> RepoProxyService.Stub.create(request)

    assert response.workflow_id == ctx.wf_id
    assert response.pipeline_id == ctx.ppl_id
    # assert response.hook_id == hook_id

    assert {:ok, hook} = HooksQueries.get_by_id(response.hook_id)
    assert get_in(hook.request, ["repository", "html_url"]) == "https://bitbucket.org/torvalds/linux"
  end

  test "create_blank() with proper params creates the workflow on plumber", ctx do
    ctx = Map.put(ctx, :integration_type, :GITHUB_APP)

    mock_projecthub(ctx)
    mock_repositoryhub(ctx)
    mock_user_service(ctx)
    mock_branch_service(ctx)

    request = %CreateBlankRequest{
      project_id: ctx.project_id,
      requester_id: ctx.requester_id,
      pipeline_id: ctx.ppl_id,
      wf_id: ctx.wf_id,
      triggered_by: :SCHEDULE,
      git: %{commit_sha: "", reference: "refs/heads/master"}
    }

    assert {:ok, channel} = GRPC.Stub.connect("localhost:50050")
    assert {:ok, response} = channel |> RepoProxyService.Stub.create_blank(request)

    assert response.wf_id == ctx.wf_id
    assert response.pipeline_id == ctx.ppl_id

    assert response.repo.owner == "torvalds"
    assert response.repo.repo_name == "linux"
    assert response.repo.branch_name == "master"
    assert response.repo.commit_sha == "commit_sha"
    assert response.repo.repository_id == ctx.repository_id

    assert {:ok, hook} = HooksQueries.get_by_id(response.hook_id)
    assert get_in(hook.request, ["repository", "html_url"]) == "https://github.com/torvalds/linux"
  end

  defp mock_projecthub(ctx) do
    ProjectHubServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.id == ctx.project_id

      %Projecthub.DescribeResponse{
        project: %{
          metadata: %{
            id: req.id,
            org_id: UUID.uuid4()
          },
          spec: %{
            repository: %{
              id: ctx.repository_id,
              owner: "torvalds",
              name: "linux",
              integration_type: ctx.integration_type || :GITHUB_OAUTH_TOKEN,
              pipeline_file: ".semaphore/semaphore.yml",
              run_on: [:BRANCHES, :TAGS],
              whitelist: %{tags: ["/v1.*/", "/release-.*/"]}
            }
          }
        },
        metadata: %{status: %{code: :OK}}
      }
    end)
  end

  defp mock_repositoryhub(ctx) do
    RepositoryServiceMock
    |> GrpcMock.expect(:describe_revision, fn req, _ ->
      assert req.repository_id == ctx.repository_id
      assert req.revision.commit_sha == ""
      assert req.revision.reference == "refs/heads/master"

      %Repository.DescribeRevisionResponse{
        commit: %{sha: "commit_sha"}
      }
    end)
  end

  defp mock_user_service(ctx) do
    UserServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.user_id == ctx.requester_id

      %User.DescribeResponse{user: %{id: ctx.requester_id, email: "john@example.com", name: "John"}}
    end)
  end

  defp mock_branch_service(ctx) do
    BranchServiceMock
    |> GrpcMock.expect(:find_or_create, fn req, _ ->
      assert req.project_id == ctx.project_id
      assert req.repository_id == ctx.repository_id
      assert req.name == "master"
      assert req.display_name == "master"
      assert req.ref_type == :BRANCH

      %Branch.FindOrCreateResponse{branch: %{id: ctx.branch_id, name: "master"}, status: %{code: :OK}}
    end)
  end

  defp mock_workflow_service(ctx) do
    WorkflowServiceMock
    |> GrpcMock.expect(:schedule, fn req, _ ->
      assert req.branch_id == ctx.branch_id
      assert req.project_id == ctx.project_id
      assert req.requester_id == ctx.requester_id
      # assert req.hook_id == hook_id

      %PlumberWF.ScheduleResponse{wf_id: ctx.wf_id, ppl_id: ctx.ppl_id, status: %{code: :OK}}
    end)
  end
end
