defmodule RepositoryHub.Server.CreateBuildStatusGuardTest do
  use RepositoryHub.ServerActionCase, async: false

  import Mock

  alias RepositoryHub.{
    BuildStatusGuard,
    GithubClient,
    GithubClientFactory,
    InternalApiFactory,
    Repo,
    RepositoryModelFactory,
    Server
  }

  alias InternalApi.Repository.CreateBuildStatusResponse

  setup do
    [_github_repo, githubapp_repo | _] = RepositoryModelFactory.seed_repositories()

    %{
      repository: githubapp_repo,
      commit_sha: Base.encode16(Ecto.UUID.generate()),
      context: "ci/semaphoreci/push: Pipeline",
      source_id: Ecto.UUID.generate()
    }
  end

  describe "create_build_status/2 with a source_id" do
    setup_with_mocks(GithubClientFactory.mocks(), context) do
      context
    end

    test "delivers a terminal status and then skips a stale pending", ctx do
      assert %CreateBuildStatusResponse{code: :OK} =
               Server.create_build_status(request(ctx, :SUCCESS), nil)

      assert %CreateBuildStatusResponse{code: :OK, skipped: true} =
               Server.create_build_status(request(ctx, :PENDING), nil)

      assert :meck.num_calls(GithubClient, :create_build_status, :_) == 1
    end

    test "delivers pending and success arriving in order", ctx do
      assert %CreateBuildStatusResponse{code: :OK, skipped: false} =
               Server.create_build_status(request(ctx, :PENDING), nil)

      assert %CreateBuildStatusResponse{code: :OK, skipped: false} =
               Server.create_build_status(request(ctx, :SUCCESS), nil)

      assert :meck.num_calls(GithubClient, :create_build_status, :_) == 2
    end

    test "delivers a pending for a new source_id after another run's terminal", ctx do
      assert %CreateBuildStatusResponse{code: :OK} =
               Server.create_build_status(request(ctx, :SUCCESS), nil)

      rerun = %{request(ctx, :PENDING) | source_id: Ecto.UUID.generate()}

      assert %CreateBuildStatusResponse{code: :OK, skipped: false} =
               Server.create_build_status(rerun, nil)

      assert :meck.num_calls(GithubClient, :create_build_status, :_) == 2
    end

    test "rejects a malformed repository_id with a validation error", ctx do
      request = %{request(ctx, :SUCCESS) | repository_id: "not-a-uuid"}

      error =
        assert_raise(GRPC.RPCError, ~r/is not valid repository id/, fn ->
          Server.create_build_status(request, nil)
        end)

      assert error.status == GRPC.Status.failed_precondition()

      assert %{rows: [[0]]} =
               Repo.query!("SELECT count(*) FROM build_status_guards WHERE commit_sha = $1", [
                 ctx.commit_sha
               ])

      assert :meck.num_calls(GithubClient, :create_build_status, :_) == 0
    end

    test "reports unavailable while another delivery holds the lease", ctx do
      request = request(ctx, :SUCCESS)
      assert {:ok, _fence} = BuildStatusGuard.claim(request)

      assert_raise GRPC.RPCError, ~r/already in progress/, fn ->
        Server.create_build_status(request, nil)
      end

      assert :meck.num_calls(GithubClient, :create_build_status, :_) == 0
    end
  end

  describe "create_build_status/2 without a source_id" do
    setup_with_mocks(GithubClientFactory.mocks(), context) do
      context
    end

    test "bypasses the guard entirely", ctx do
      request = %{request(ctx, :SUCCESS) | source_id: ""}

      assert %CreateBuildStatusResponse{code: :OK, skipped: false} =
               Server.create_build_status(request, nil)

      assert %{rows: [[0]]} =
               Repo.query!("SELECT count(*) FROM build_status_guards WHERE commit_sha = $1", [
                 ctx.commit_sha
               ])

      assert :meck.num_calls(GithubClient, :create_build_status, :_) == 1
    end
  end

  defp request(ctx, status) do
    InternalApiFactory.create_build_status_request(
      repository_id: ctx.repository.id,
      commit_sha: ctx.commit_sha,
      context: ctx.context,
      source_id: ctx.source_id,
      status: status
    )
  end
end
