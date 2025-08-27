defmodule FrontWeb.AccountControllerTest do
  use FrontWeb.ConnCase

  setup do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = Support.Stubs.User.default()
    org = Support.Stubs.Organization.default()

    conn =
      build_conn(:get, "https://me.semaphoretest.test", nil)
      |> put_req_header("x-semaphore-user-id", user.id)

    [
      conn: conn,
      org_id: org.id
    ]
  end

  describe "GET show" do
    test "when the user has github private scope and miss bitbucket => shows correct options", %{
      conn: conn
    } do
      conn =
        conn
        |> get("/account")

      assert get_req_header(conn, "x-semaphore-org-id") == []
      assert html_response(conn, 200) =~ "/account/update_repo_scope/bitbucket"
      refute html_response(conn, 200) =~ "/account/update_repo_scope/github"
    end

    test "when bitbucket feature is disabled => do not show bitbucket scope", %{
      conn: conn
    } do
      Support.Stubs.Feature.setup_feature("bitbucket", state: :HIDDEN, quantity: 0)

      conn =
        conn
        |> get("/account")

      refute html_response(conn, 200) =~ "Bitbucket"
      assert html_response(conn, 200) =~ "GitHub"

      Support.Stubs.Feature.setup_feature("bitbucket", state: :ENABLED, quantity: 1)
    end
  end

  describe "POST update" do
    test "when entered params don't pass user model validation => it returns 422, displays the show user page with user-provided params and alerts",
         %{conn: conn} do
      conn =
        conn
        |> post("/account", %{})

      assert html_response(conn, 422) =~ "Required. Cannot be empty."
      assert get_flash(conn, :alert) == "Failed to update the account..."
    end

    test "when updating the user fails with name attribute error, it returns 422, alerts, shows user provided input in the form",
         %{conn: conn} do
      GrpcMock.stub(
        UserMock,
        :update,
        InternalApi.User.UpdateResponse.new(
          status:
            Google.Rpc.Status.new(
              code: Google.Rpc.Code.value(:INTERNAL),
              message: "Oops! Something went wrong with the name field."
            )
        )
      )

      conn =
        conn
        |> post("/account", %{name: "Perica"})

      assert get_req_header(conn, "x-semaphore-org-id") == []
      assert html_response(conn, 422) =~ "Perica"
      assert html_response(conn, 422) =~ "Oops! Something went wrong with the name field."
      assert get_flash(conn, :alert) == "Failed to update the account..."
    end

    test "when updating the user fails with an arbitrary error, it returns 422, alerts, shows user provided input in the form",
         %{conn: conn} do
      GrpcMock.stub(
        UserMock,
        :update,
        InternalApi.User.UpdateResponse.new(
          status:
            Google.Rpc.Status.new(
              code: Google.Rpc.Code.value(:INTERNAL),
              message: "Oops! Something went wrong."
            )
        )
      )

      conn =
        conn
        |> post("/account", %{name: "Perica"})

      assert get_req_header(conn, "x-semaphore-org-id") == []
      assert html_response(conn, 422) =~ "Perica"
      assert get_flash(conn, :alert) == "Failed: Oops! Something went wrong."
    end
  end

  describe "POST reset_token" do
    test "when there is an error updating the user => redirects with errors", %{conn: conn} do
      GrpcMock.stub(
        UserMock,
        :regenerate_token,
        InternalApi.User.RegenerateTokenResponse.new(
          status:
            Google.Rpc.Status.new(
              code: Google.Rpc.Code.value(:INTERNAL),
              message: "Oops! Something went wrong."
            )
        )
      )

      conn =
        conn
        |> post("/account/reset_token")

      assert get_req_header(conn, "x-semaphore-org-id") == []
      assert conn.resp_body =~ "An error occurred while regenerating the API token"
    end
  end

  describe "POST update_repo_scope" do
    test "when the new scope is public => redirects externally with public scope", %{conn: conn} do
      conn =
        conn
        |> post("/account/update_repo_scope/github", %{access_level: "public"})

      assert get_req_header(conn, "x-semaphore-org-id") == []
      assert redirected_to(conn) =~ "public_repo,user:email"
    end

    test "when the new scope is private => redirects externally with private scope", %{conn: conn} do
      conn =
        conn
        |> post("/account/update_repo_scope/github", %{access_level: "private"})

      assert get_req_header(conn, "x-semaphore-org-id") == []
      assert redirected_to(conn) =~ "repo,user:email"
    end
  end
end
