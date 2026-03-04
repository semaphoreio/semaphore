defmodule FrontWeb.MeControllerTest do
  use FrontWeb.ConnCase
  alias Support.Stubs.DB

  setup %{conn: _conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = Support.Stubs.User.default()

    organization = Support.Stubs.Organization.default()
    project = DB.first(:projects)

    conn =
      build_conn(:get, "https://me.semaphoreci.com", nil)
      |> put_req_header("x-semaphore-user-id", user.id)

    [
      conn: conn,
      organization: organization,
      user: user,
      project: project
    ]
  end

  describe "GET show" do
    test "returns list of organizations", %{conn: conn, user: user} do
      %{id: org_id} = Support.Stubs.Organization.create(name: "FOooo")
      Support.Stubs.RBAC.add_member(org_id, user.id, nil)

      conn =
        conn
        |> get("/")

      assert html_response(conn, 200) =~ "Select one of your organizations to continue:"
      refute html_response(conn, 200) =~ "signup"
      assert html_response(conn, 200) =~ "new organization"
    end

    test "when the user has no orgs => redirects organization onboarding", %{conn: conn} do
      DB.clear(:organizations)

      conn =
        conn
        |> get("/")

      assert redirected_to(conn) =~ organization_onboarding_path(conn, :new)
    end

    test "when the user has one org => redirect to it", %{conn: conn} do
      conn =
        conn
        |> get("/")

      assert redirected_to(conn) =~ "/"
    end

    test "when single tenant => do not show create new organization", %{
      conn: conn,
      user: user
    } do
      %{id: org_id} = Support.Stubs.Organization.create(name: "FOooo")
      Support.Stubs.RBAC.add_member(org_id, user.id, nil)

      Application.put_env(:front, :single_tenant, true)
      conn = conn |> get("/")

      refute html_response(conn, 200) =~ "new organization"
      Application.put_env(:front, :single_tenant, false)
    end
  end

  describe "GET github_app_installation" do
    setup %{organization: organization} do
      Support.Stubs.Feature.disable_feature(organization.id, :new_project_onboarding)
      :ok
    end

    test "when the user has no orgs => redirects to me page", %{conn: conn} do
      DB.clear(:organizations)

      conn =
        conn
        |> get("/github_app_installation")

      assert redirected_to(conn) =~ "/"
    end

    test "if user has one org => redirect to it", %{conn: conn, organization: organization} do
      conn =
        conn
        |> get("/github_app_installation")

      assert redirected_to(conn) =~
               "//#{organization.api_model.org_username}.semaphoretest.test/github/choose_repository"
    end

    test "if user has more orgs => list them", %{
      conn: conn,
      organization: organization,
      user: user
    } do
      org1 = Support.Stubs.Organization.create(owner_id: user.id).api_model

      DB.insert(:subject_role_bindings, %{
        id: Ecto.UUID.generate(),
        org_id: org1.org_id,
        subject_id: user.id,
        role_id: Ecto.UUID.generate(),
        project_id: nil
      })

      org2 = organization.api_model

      conn =
        conn
        |> get("/github_app_installation")

      assert html_response(conn, 200) =~ "Select one of your organizations to continue:"
      assert html_response(conn, 200) =~ org1.org_username
      assert html_response(conn, 200) =~ org2.org_username

      assert html_response(conn, 200) =~
               "//#{org1.org_username}.semaphoretest.test/github/choose_repository"
    end

    test "when state doesnt exists => redirects to page without state", %{conn: conn} do
      conn =
        conn
        |> get("/github_app_installation?state=asd")

      assert redirected_to(conn) =~ "/github_app_installation"
    end

    test "when org from state doesnt exists => redirects to page without state", %{conn: conn} do
      conn =
        conn
        |> get("/github_app_installation?state=o_asd")

      assert redirected_to(conn) =~ "/github_app_installation"
    end

    test "when org from state exists => redirects to it", %{
      conn: conn,
      organization: organization
    } do
      conn =
        conn
        |> get("/github_app_installation?state=o_#{organization.id}")

      assert redirected_to(conn) =~
               "//#{organization.api_model.org_username}.semaphoretest.test/github/choose_repository"
    end

    test "when project from state doesnt exists => redirects to page without state", %{conn: conn} do
      conn =
        conn
        |> get("/github_app_installation?state=p_asd")

      assert redirected_to(conn) =~ "/github_app_installation"
    end

    test "when project from state exists => redirects to it", %{
      conn: conn,
      project: project,
      organization: organization
    } do
      conn =
        conn
        |> get("/github_app_installation?state=p_#{project.id}")

      assert redirected_to(conn) =~
               "//#{organization.api_model.org_username}.semaphoretest.test/projects/#{project.name}/settings/repository"
    end
  end
end
