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

    test "suppressed statuses never reach the provider", ctx do
      suppressed = %{request(ctx, :PENDING) | suppress: true}

      assert %CreateBuildStatusResponse{code: :OK, skipped: true} =
               Server.create_build_status(suppressed, nil)

      assert :meck.num_calls(GithubClient, :create_build_status, :_) == 0
    end

    test "a suppressed terminal status still reconciles an outstanding pending", ctx do
      assert %CreateBuildStatusResponse{code: :OK, skipped: false} =
               Server.create_build_status(request(ctx, :PENDING), nil)

      suppressed_success = %{request(ctx, :SUCCESS) | suppress: true}

      assert %CreateBuildStatusResponse{code: :OK, skipped: false} =
               Server.create_build_status(suppressed_success, nil)

      # the pending went out, so the terminal must follow it - a check is never
      # left pending forever because the policy flipped mid-pipeline
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

    test "rejects a malformed repository_id with a validation error, not a guard outage", ctx do
      request = %{request(ctx, :SUCCESS) | repository_id: "not-a-uuid"}

      with_mock Watchman, [:passthrough], [] do
        log =
          ExUnit.CaptureLog.capture_log(fn ->
            error =
              assert_raise(GRPC.RPCError, ~r/is not valid repository id/, fn ->
                Server.create_build_status(request, nil)
              end)

            assert error.status == GRPC.Status.failed_precondition()
          end)

        refute log =~ "guard unavailable"
        assert_not_called(Watchman.increment("build_status_guard.unavailable"))
      end

      assert %{rows: [[0]]} =
               Repo.query!("SELECT count(*) FROM build_status_guards WHERE commit_sha = $1", [
                 ctx.commit_sha
               ])

      assert :meck.num_calls(GithubClient, :create_build_status, :_) == 0
    end

    test "releases the lease when the provider definitively rejects the status", ctx do
      :meck.expect(GithubClient, :create_build_status, fn _params, _opts ->
        {:error, "Can't create a commit status on GitHub."}
      end)

      request = request(ctx, :SUCCESS)

      assert_raise GRPC.RPCError, fn -> Server.create_build_status(request, nil) end

      assert {:ok, _fence} = BuildStatusGuard.claim(request)
    end

    test "holds the lease when the send outcome is unknown", ctx do
      :meck.expect(GithubClient, :create_build_status, fn _params, _opts ->
        raise "recv timeout"
      end)

      request = request(ctx, :SUCCESS)

      assert_raise GRPC.RPCError, fn -> Server.create_build_status(request, nil) end

      assert :busy = BuildStatusGuard.claim(request)
    end

    test "holds the lease when the provider reports unavailable", ctx do
      :meck.expect(GithubClient, :create_build_status, fn _params, _opts ->
        {:error, %{status: GRPC.Status.unavailable(), message: "GitHub is unavailable."}}
      end)

      request = request(ctx, :SUCCESS)

      assert_raise GRPC.RPCError, ~r/unavailable/i, fn ->
        Server.create_build_status(request, nil)
      end

      assert :busy = BuildStatusGuard.claim(request)
    end

    test "delivers unguarded while the guard table is missing", ctx do
      with_mock BuildStatusGuard, [:passthrough], claim: fn _request -> {:error, :guard_unavailable} end do
        assert %CreateBuildStatusResponse{code: :OK, skipped: false} =
                 Server.create_build_status(request(ctx, :SUCCESS), nil)
      end

      assert :meck.num_calls(GithubClient, :create_build_status, :_) == 1
    end

    test "fails delivery for retry on a transient guard error", ctx do
      with_mock BuildStatusGuard, [:passthrough],
        claim: fn _request -> {:error, %DBConnection.ConnectionError{message: "tcp recv"}} end do
        error =
          assert_raise(GRPC.RPCError, ~r/guard is unavailable/, fn ->
            Server.create_build_status(request(ctx, :SUCCESS), nil)
          end)

        assert error.status == GRPC.Status.unavailable()
      end

      assert :meck.num_calls(GithubClient, :create_build_status, :_) == 0
    end

    test "forces redelivery when finalize fails after a successful send", ctx do
      with_mock BuildStatusGuard, [:passthrough],
        finalize: fn _request, _fence -> {:error, %DBConnection.ConnectionError{message: "tcp"}} end do
        error =
          assert_raise(GRPC.RPCError, ~r/delivered but not recorded/, fn ->
            Server.create_build_status(request(ctx, :SUCCESS), nil)
          end)

        assert error.status == GRPC.Status.unavailable()

        assert :meck.num_calls(GithubClient, :create_build_status, :_) == 1
        assert :busy = BuildStatusGuard.claim(request(ctx, :SUCCESS))
      end
    end

    test "a failing release does not mask the provider rejection", ctx do
      :meck.expect(GithubClient, :create_build_status, fn _params, _opts ->
        {:error, "Can't create a commit status on GitHub."}
      end)

      with_mock BuildStatusGuard, [:passthrough],
        release: fn _request, _fence -> {:error, %DBConnection.ConnectionError{message: "tcp"}} end do
        error =
          assert_raise(GRPC.RPCError, fn ->
            Server.create_build_status(request(ctx, :SUCCESS), nil)
          end)

        assert error.status == GRPC.Status.failed_precondition()
      end
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
