defmodule FrontWeb.AccountControllerTest do
  use FrontWeb.ConnCase

  @oauth_error_codes ~w(invalid_uid missing_name missing_login auth_failed login_not_allowed)

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
      assert html_response(conn, 200) =~ "Danger Zone"
      assert html_response(conn, 200) =~ "transfer ownership"
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

    test "when email_members feature is disabled => hides update email form", %{
      conn: conn
    } do
      Support.Stubs.Feature.setup_feature("email_members", state: :HIDDEN, quantity: 0)

      conn =
        conn
        |> get("/account")

      refute html_response(conn, 200) =~ "id=\"email-form\""
      refute html_response(conn, 200) =~ "Update Email"
    end

    test "when status=error with invalid_uid code => sets :alert flash with mapped text", %{
      conn: conn
    } do
      conn = get(conn, "/account", %{"status" => "error", "code" => "invalid_uid"})

      assert html_response(conn, 200)
      assert get_flash(conn, :alert) =~ "did not return the required profile data"
    end

    test "when status=error with missing_name code => sets :alert flash with mapped text", %{
      conn: conn
    } do
      conn = get(conn, "/account", %{"status" => "error", "code" => "missing_name"})

      assert html_response(conn, 200)
      assert get_flash(conn, :alert) =~ "profile is missing a display name"
    end

    test "when status=error with missing_login code => sets :alert flash with mapped text", %{
      conn: conn
    } do
      conn = get(conn, "/account", %{"status" => "error", "code" => "missing_login"})

      assert html_response(conn, 200)
      assert get_flash(conn, :alert) =~ "profile is missing a username"
    end

    test "when status=error with unknown code => sets generic :alert flash", %{conn: conn} do
      conn = get(conn, "/account", %{"status" => "error", "code" => "bogus"})

      assert html_response(conn, 200)
      assert get_flash(conn, :alert) =~ "connection attempt was unsuccessful"
    end

    test "when status=error with attacker text in code => still falls to generic, no reflection",
         %{conn: conn} do
      conn =
        get(conn, "/account", %{
          "status" => "error",
          "code" => "<script>alert(1)</script>"
        })

      assert html_response(conn, 200)
      assert get_flash(conn, :alert) =~ "connection attempt was unsuccessful"
      refute get_flash(conn, :alert) =~ "<script>"
    end

    test "when status=error without code => sets generic :alert flash", %{conn: conn} do
      conn = get(conn, "/account", %{"status" => "error"})

      assert html_response(conn, 200)
      assert get_flash(conn, :alert) =~ "connection attempt was unsuccessful"
    end

    test "when status=success => sets :notice flash", %{conn: conn} do
      conn = get(conn, "/account", %{"status" => "success"})

      assert html_response(conn, 200)
      assert get_flash(conn, :notice) == "Repository account connected."
    end

    test "when no status param => no flash set from oauth path", %{conn: conn} do
      conn = get(conn, "/account")

      assert html_response(conn, 200)
      assert get_flash(conn, :alert) == nil
      assert get_flash(conn, :notice) == nil
    end

    test "every declared oauth error code maps to a non-generic flash message",
         %{conn: conn} do
      generic =
        "We're sorry, but your connection attempt was unsuccessful. Please try again. " <>
          "If you continue to experience issues, please contact our support team for assistance."

      for code <- @oauth_error_codes do
        conn = get(conn, "/account", %{"status" => "error", "code" => code})

        flash = get_flash(conn, :alert)

        assert is_binary(flash), "code #{inspect(code)} produced no :alert flash"

        refute flash == generic,
               "code #{inspect(code)} fell through to generic copy — add an oauth_error_text/1 clause"
      end
    end
  end

  describe "POST delete_with_owned_orgs" do
    test "deletes account and redirects to destroyed account page", %{conn: conn} do
      conn =
        conn
        |> post("/account/delete_with_owned_orgs")

      assert redirected_to(conn) == "https://id.semaphoretest.test/destroyed_account"
    end

    test "when deletion fails => redirects back to account with alert", %{conn: conn} do
      user = Support.Stubs.User.default()
      Support.Stubs.User.delete(user.id)

      conn =
        conn
        |> post("/account/delete_with_owned_orgs")

      assert redirected_to(conn) == "/account"
      assert get_flash(conn, :alert) == "Failed to delete account."
    end

    test "when backend rejects with a precondition => surfaces the backend message", %{
      conn: conn
    } do
      message =
        "You are the last owner of organization(s): Acme. " <>
          "Transfer ownership or delete the organization first before you can delete your account."

      GrpcMock.stub(UserMock, :delete_with_owned_orgs, fn _req, _ ->
        raise GRPC.RPCError, status: GRPC.Status.failed_precondition(), message: message
      end)

      conn =
        conn
        |> post("/account/delete_with_owned_orgs")

      assert redirected_to(conn) == "/account"
      assert get_flash(conn, :alert) == message
    end
  end

  describe "POST change_my_email" do
    test "successfully changes user email when feature enabled", %{conn: conn} do
      Support.Stubs.Feature.setup_feature("email_members", state: :ENABLED, quantity: 1)

      conn = post(conn, "/account/change_email", %{"email" => "new@example.com"})

      assert redirected_to(conn, 302) == "/account"
      assert get_flash(conn, :notice) == "Updated email"
    end

    test "handles invalid email format", %{conn: conn} do
      Support.Stubs.Feature.setup_feature("email_members", state: :ENABLED, quantity: 1)

      conn = post(conn, "/account/change_email", %{"email" => "invalid-email"})

      assert redirected_to(conn, 302) == "/account"
      assert get_flash(conn, :alert) == "Please enter a valid email address."
    end

    test "handles empty email", %{conn: conn} do
      Support.Stubs.Feature.setup_feature("email_members", state: :ENABLED, quantity: 1)

      conn = post(conn, "/account/change_email", %{"email" => ""})

      assert redirected_to(conn, 302) == "/account"
      assert get_flash(conn, :alert) == "Email address cannot be empty."
    end

    test "handles backend error gracefully", %{conn: conn} do
      Support.Stubs.Feature.setup_feature("email_members", state: :ENABLED, quantity: 1)

      # Setup stub to return error
      GrpcMock.stub(GuardMock, :change_email, fn %{user_id: "fail"}, _ ->
        {:error, %GRPC.RPCError{message: "User not found"}}
      end)

      conn =
        conn
        |> put_req_header("x-semaphore-user-id", "fail")
        |> post("/account/change_email", %{"email" => "new@example.com"})

      assert redirected_to(conn, 302) == "/account"
      assert get_flash(conn, :alert) =~ "Failed to update email:"
    end

    test "returns 404 when feature is disabled", %{conn: conn} do
      Support.Stubs.Feature.setup_feature("email_members", state: :HIDDEN, quantity: 0)

      conn = post(conn, "/account/change_email", %{"email" => "new@example.com"})

      assert response(conn, 404)
    end
  end

  describe "POST reset_my_password" do
    test "successfully resets password when feature enabled", %{conn: conn} do
      Support.Stubs.Feature.setup_feature("email_members", state: :ENABLED, quantity: 1)

      conn = post(conn, "/account/reset_my_password")

      assert html_response(conn, 200) =~ "New Temporary Password"
      assert get_flash(conn, :notice) == "Password reset"
    end

    test "prevents password reset when feature disabled", %{conn: conn} do
      Support.Stubs.Feature.setup_feature("email_members", state: :HIDDEN, quantity: 0)

      conn = post(conn, "/account/reset_my_password")

      assert html_response(conn, 200) =~ "Password changes are not enabled"
      assert get_flash(conn, :alert) == "Password changes are not enabled for your organization."
    end

    test "handles backend error gracefully", %{conn: conn} do
      Support.Stubs.Feature.setup_feature("email_members", state: :ENABLED, quantity: 1)

      # Setup stub to return error
      GrpcMock.stub(GuardMock, :reset_password, fn %{user_id: "fail"}, _ ->
        {:error, %GRPC.RPCError{message: "Password reset failed"}}
      end)

      conn =
        conn
        |> post("/account/reset_my_password")

      assert html_response(conn, 200)
      assert get_flash(conn, :alert) =~ "Failed to reset password:"
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
