defmodule FrontWeb.ProjectOnboardingControllerTest do
  use FrontWeb.ConnCase
  import ExUnit.CaptureLog
  alias Support.Stubs.DB

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = Support.Stubs.User.default()
    organization = Support.Stubs.Organization.default()
    project = DB.first(:projects)

    conn =
      conn
      |> put_req_header("x-semaphore-org-id", organization.id)
      |> put_req_header("x-semaphore-user-id", user.id)

    [
      conn: conn,
      organization: organization,
      user: user,
      project: project
    ]
  end

  describe "GET invite_collaborators" do
    test "returns 200", %{conn: conn, project: project} do
      conn =
        conn
        |> get("/projects/#{project.name}/invite_collaborators")

      assert html_response(conn, 200)
    end
  end

  describe "POST create" do
    test "provides helpful default error message when project creation fails", %{conn: conn} do
      GrpcMock.stub(ProjecthubMock, :create, fn _, _ ->
        InternalApi.Projecthub.CreateResponse.new(
          metadata:
            InternalApi.Projecthub.ResponseMeta.new(
              status:
                InternalApi.Projecthub.ResponseMeta.Status.new(
                  code: InternalApi.Projecthub.ResponseMeta.Code.value(:FAILED_PRECONDITION)
                )
            )
        )
      end)

      conn =
        conn
        |> post("/projects", %{
          url: "git@github.com:renderedtext/front.git",
          integration_type: "github_app",
          name: "BAR"
        })

      json = json_response(conn, 200)
      assert json["error"] == "Project creation failed"
    end

    test "provides helpful error message when project creation fails", %{conn: conn} do
      GrpcMock.stub(ProjecthubMock, :create, fn _, _ ->
        InternalApi.Projecthub.CreateResponse.new(
          metadata:
            InternalApi.Projecthub.ResponseMeta.new(
              status:
                InternalApi.Projecthub.ResponseMeta.Status.new(
                  code: InternalApi.Projecthub.ResponseMeta.Code.value(:FAILED_PRECONDITION),
                  message: "Error from projecthub"
                )
            )
        )
      end)

      conn =
        conn
        |> post("/projects", %{
          url: "git@github.com:renderedtext/front.git",
          integration_type: "github_app",
          name: "BAR"
        })

      json = json_response(conn, 200)
      assert json["error"] == "Error from projecthub"
    end
  end

  describe "GET repositories" do
    test "returns repositories payload on success", %{conn: conn} do
      conn =
        conn
        |> get("/repositories?integration_type=bitbucket&page_token=")

      body = json_response(conn, 200)

      assert is_list(body["repos"])
      assert Map.has_key?(body, "next_page_token")
    end

    test "returns structured JSON error on repository service failure", %{conn: conn} do
      GrpcMock.stub(RepositoryMock, :list_accessible_repositories, fn _, _ ->
        raise GRPC.RPCError, status: GRPC.Status.unavailable(), message: "Repository service down"
      end)

      conn =
        conn
        |> get("/repositories?integration_type=bitbucket&page_token=")

      body = json_response(conn, 503)

      assert body == %{
               "error" => "repository_service_unavailable",
               "message" => "Failed to load repositories. Please retry."
             }
    end
  end

  describe "POST refresh" do
    alias InternalApi.RepositoryIntegrator.RefreshRepositoriesResponse

    defp stub_refresh(state, message) do
      GrpcMock.stub(
        RepositoryIntegratorMock,
        :refresh_repositories,
        RefreshRepositoriesResponse.new(
          sync_state: RefreshRepositoriesResponse.SyncState.value(state),
          message: message
        )
      )
    end

    test "fails a github_app refresh with neither a repository nor an organization", %{conn: conn} do
      stub_refresh(:FAILED, "Specify a repository or organization to refresh.")

      conn = post(conn, "/x/repositories/refresh", %{integration_type: "github_app"})

      body = json_response(conn, 422)
      assert body["state"] == "failed"
      assert body["message"] =~ "repository or organization"
    end

    test "rate limits an immediate second org/full refresh with the 10-minute window", %{
      conn: conn
    } do
      stub_refresh(:STARTED, "Repository sync started for acme.")
      params = %{integration_type: "github_app", organization: "acme"}

      assert conn |> post("/x/repositories/refresh", params) |> json_response(200)

      conn = post(conn, "/x/repositories/refresh", params)

      body = json_response(conn, 429)
      assert body["state"] == "rate_limited"
      assert is_integer(body["retry_after"])
      # Fixed 10-minute full/org cooldown, distinct from the 60s targeted throttle.
      assert body["retry_after"] > 60
      assert body["retry_after"] <= 600
    end

    test "an already running sync still consumes the cooldown", %{conn: conn} do
      stub_refresh(:ALREADY_RUNNING, "A repository sync is already running.")
      params = %{integration_type: "github_app", organization: "acme"}

      assert conn
             |> post("/x/repositories/refresh", params)
             |> json_response(200)
             |> Map.fetch!("state") == "already_running"

      conn = post(conn, "/x/repositories/refresh", params)
      assert json_response(conn, 429)
    end

    test "targeted refresh passes the slug through and is then rate limited", %{conn: conn} do
      test_pid = self()

      GrpcMock.stub(RepositoryIntegratorMock, :refresh_repositories, fn req, _ ->
        send(test_pid, {:refresh_request, req})

        RefreshRepositoriesResponse.new(
          sync_state: RefreshRepositoriesResponse.SyncState.value(:STARTED),
          message: "Refreshing octo/repo from GitHub."
        )
      end)

      params = %{integration_type: "github_app", repository_slug: "octo/repo"}

      assert conn
             |> post("/x/repositories/refresh", params)
             |> json_response(200)
             |> Map.fetch!("state") == "started"

      assert_received {:refresh_request, req}
      assert req.repository_slug == "octo/repo"

      # Targeted refreshes are throttled per user, so an immediate retry is limited.
      conn = post(conn, "/x/repositories/refresh", params)
      assert json_response(conn, 429)["state"] == "rate_limited"
    end

    test "throttles a second targeted refresh even for a different slug", %{conn: conn} do
      stub_refresh(:STARTED, "Refreshing from GitHub.")

      assert conn
             |> post("/x/repositories/refresh", %{
               integration_type: "github_app",
               repository_slug: "octo/repo"
             })
             |> json_response(200)

      # A different slug must not bypass the per-user targeted throttle — that is
      # exactly what an enumeration/abuse loop would do.
      conn =
        post(conn, "/x/repositories/refresh", %{
          integration_type: "github_app",
          repository_slug: "octo/other"
        })

      assert json_response(conn, 429)["state"] == "rate_limited"
    end

    test "targeted and org/full refreshes throttle independently", %{conn: conn} do
      stub_refresh(:STARTED, "started")

      assert conn
             |> post("/x/repositories/refresh", %{
               integration_type: "github_app",
               repository_slug: "octo/repo"
             })
             |> json_response(200)

      # A targeted cooldown must not block an org refresh (separate scope).
      conn =
        post(conn, "/x/repositories/refresh", %{
          integration_type: "github_app",
          organization: "acme"
        })

      assert json_response(conn, 200)["state"] == "started"
    end

    test "organization refresh passes the org through and consumes the cooldown", %{conn: conn} do
      test_pid = self()

      GrpcMock.stub(RepositoryIntegratorMock, :refresh_repositories, fn req, _ ->
        send(test_pid, {:refresh_request, req})

        RefreshRepositoriesResponse.new(
          sync_state: RefreshRepositoriesResponse.SyncState.value(:STARTED),
          message: "Repository sync started for acme."
        )
      end)

      params = %{integration_type: "github_app", organization: "acme"}

      assert conn
             |> post("/x/repositories/refresh", params)
             |> json_response(200)
             |> Map.fetch!("state") == "started"

      assert_received {:refresh_request, req}
      assert req.organization == "acme"
      assert req.repository_slug == ""

      # An org refresh is a full refresh, so an immediate retry is rate limited.
      conn = post(conn, "/x/repositories/refresh", params)
      assert json_response(conn, 429)
    end

    test "rejects an invalid organization without calling the RPC", %{conn: conn} do
      GrpcMock.stub(RepositoryIntegratorMock, :refresh_repositories, fn _, _ ->
        raise "refresh_repositories must not be called"
      end)

      conn =
        post(conn, "/x/repositories/refresh", %{
          integration_type: "github_app",
          organization: "not a valid org!"
        })

      body = json_response(conn, 422)
      assert body["state"] == "failed"
      assert body["message"] =~ "organization"
    end

    test "rejects an invalid slug without calling the RPC", %{conn: conn} do
      GrpcMock.stub(RepositoryIntegratorMock, :refresh_repositories, fn _, _ ->
        raise "refresh_repositories must not be called"
      end)

      conn =
        post(conn, "/x/repositories/refresh", %{
          integration_type: "github_app",
          repository_slug: "not a slug"
        })

      body = json_response(conn, 422)
      assert body["state"] == "failed"
      assert body["message"] =~ "owner/repository"
    end

    test "short-circuits integration types without a cache", %{conn: conn} do
      GrpcMock.stub(RepositoryIntegratorMock, :refresh_repositories, fn _, _ ->
        raise "refresh_repositories must not be called"
      end)

      conn = post(conn, "/x/repositories/refresh", %{integration_type: "bitbucket"})

      body = json_response(conn, 200)
      assert body["state"] == "done"
    end

    test "releases the cooldown when the RPC fails", %{conn: conn} do
      GrpcMock.stub(RepositoryIntegratorMock, :refresh_repositories, fn _, _ ->
        raise GRPC.RPCError, status: GRPC.Status.unavailable(), message: "down"
      end)

      params = %{integration_type: "github_app", organization: "acme"}

      assert conn
             |> post("/x/repositories/refresh", params)
             |> json_response(503)
             |> Map.fetch!("state") == "failed"

      stub_refresh(:STARTED, "Repository sync started for acme.")

      conn = post(conn, "/x/repositories/refresh", params)
      assert json_response(conn, 200)["state"] == "started"
    end

    test "a failed org/full refresh does not consume the cooldown", %{conn: conn} do
      stub_refresh(:FAILED, "The GitHub App has no access to acme. Grant access on GitHub first.")
      params = %{integration_type: "github_app", organization: "acme"}

      assert conn
             |> post("/x/repositories/refresh", params)
             |> json_response(422)
             |> Map.fetch!("state") == "failed"

      # The no-op failure released the cooldown, so an immediate retry is allowed
      # rather than rate limited.
      stub_refresh(:STARTED, "Repository sync started for acme.")

      conn = post(conn, "/x/repositories/refresh", params)
      assert json_response(conn, 200)["state"] == "started"
    end

    test "a failed targeted refresh still consumes the cooldown", %{conn: conn} do
      stub_refresh(:FAILED, "The GitHub App has no access to octo/repo.")

      params = %{integration_type: "github_app", repository_slug: "octo/repo"}

      assert conn
             |> post("/x/repositories/refresh", params)
             |> json_response(422)
             |> Map.fetch!("state") == "failed"

      # The cooldown is kept on a failed targeted refresh so denied slugs cannot be
      # looped — an immediate retry is rate limited.
      conn = post(conn, "/x/repositories/refresh", params)
      assert json_response(conn, 429)["state"] == "rate_limited"
    end

    test "maps a failed refresh to 422 with the server message", %{conn: conn} do
      stub_refresh(:FAILED, "The GitHub App has no access to octo/repo.")

      conn =
        post(conn, "/x/repositories/refresh", %{
          integration_type: "github_app",
          repository_slug: "octo/repo"
        })

      body = json_response(conn, 422)
      assert body["state"] == "failed"
      assert body["message"] =~ "no access"
    end

    test "writes an audit event when a refresh reaches the provider", %{conn: conn} do
      log =
        capture_log(fn ->
          assert conn
                 |> post("/x/repositories/refresh", %{
                   integration_type: "github_app",
                   repository_slug: "octo/repo"
                 })
                 |> json_response(200)
        end)

      assert log =~ "AuditLog"
    end

    test "does not write an audit event when the slug is rejected before the RPC", %{conn: conn} do
      log =
        capture_log(fn ->
          assert conn
                 |> post("/x/repositories/refresh", %{
                   integration_type: "github_app",
                   repository_slug: "not a slug"
                 })
                 |> json_response(422)
        end)

      refute log =~ "AuditLog"
    end
  end
end
