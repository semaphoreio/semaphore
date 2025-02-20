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
end
