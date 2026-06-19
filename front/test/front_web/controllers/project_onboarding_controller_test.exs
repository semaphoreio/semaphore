defmodule FrontWeb.ProjectOnboardingControllerTest do
  use FrontWeb.ConnCase
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

    test "starts a full refresh for github_app", %{conn: conn} do
      conn = post(conn, "/x/repositories/refresh", %{integration_type: "github_app"})

      body = json_response(conn, 200)
      assert body["state"] == "started"
      assert body["message"] == "Repository sync started."
    end

    test "rate limits an immediate second full refresh", %{conn: conn} do
      assert conn
             |> post("/x/repositories/refresh", %{integration_type: "github_app"})
             |> json_response(200)

      conn = post(conn, "/x/repositories/refresh", %{integration_type: "github_app"})

      body = json_response(conn, 429)
      assert body["state"] == "rate_limited"
      assert is_integer(body["retry_after"])
      assert body["retry_after"] <= 60
    end

    test "an already running sync still consumes the cooldown", %{conn: conn} do
      stub_refresh(:ALREADY_RUNNING, "A repository sync is already running.")

      assert conn
             |> post("/x/repositories/refresh", %{integration_type: "github_app"})
             |> json_response(200)
             |> Map.fetch!("state") == "already_running"

      conn = post(conn, "/x/repositories/refresh", %{integration_type: "github_app"})
      assert json_response(conn, 429)
    end

    test "targeted refresh passes the slug through and is not rate limited", %{conn: conn} do
      test_pid = self()

      GrpcMock.stub(RepositoryIntegratorMock, :refresh_repositories, fn req, _ ->
        send(test_pid, {:refresh_request, req})

        RefreshRepositoriesResponse.new(
          sync_state: RefreshRepositoriesResponse.SyncState.value(:DONE),
          message: "Repository octo/repo refreshed."
        )
      end)

      params = %{integration_type: "github_app", repository_slug: "octo/repo"}

      assert conn
             |> post("/x/repositories/refresh", params)
             |> json_response(200)
             |> Map.fetch!("state") == "done"

      assert_received {:refresh_request, req}
      assert req.repository_slug == "octo/repo"

      assert conn
             |> post("/x/repositories/refresh", params)
             |> json_response(200)
             |> Map.fetch!("state") == "done"
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

      assert conn
             |> post("/x/repositories/refresh", %{integration_type: "github_app"})
             |> json_response(503)
             |> Map.fetch!("state") == "failed"

      stub_refresh(:STARTED, "Repository sync started.")

      conn = post(conn, "/x/repositories/refresh", %{integration_type: "github_app"})
      assert json_response(conn, 200)["state"] == "started"
    end

    test "a failed full refresh does not consume the cooldown", %{conn: conn} do
      stub_refresh(
        :FAILED,
        "No GitHub App repositories to refresh. Install the GitHub App first."
      )

      assert conn
             |> post("/x/repositories/refresh", %{integration_type: "github_app"})
             |> json_response(422)
             |> Map.fetch!("state") == "failed"

      # The no-op failure released the cooldown, so an immediate retry is allowed
      # rather than rate limited.
      stub_refresh(:STARTED, "Repository sync started.")

      conn = post(conn, "/x/repositories/refresh", %{integration_type: "github_app"})
      assert json_response(conn, 200)["state"] == "started"
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
  end
end
