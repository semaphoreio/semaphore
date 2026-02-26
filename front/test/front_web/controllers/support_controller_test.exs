defmodule FrontWeb.SupportControllerTest do
  use FrontWeb.ConnCase
  import Mock

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = Support.Stubs.User.default()
    organization = Support.Stubs.Organization.default()

    conn =
      conn
      |> put_req_header("x-semaphore-org-id", organization.id)
      |> put_req_header("x-semaphore-user-id", user.id)

    [
      conn: conn,
      organization: organization,
      user: user
    ]
  end

  describe "GET new" do
    test "when the user is not authorized to view the org, it renders 404", %{
      conn: conn,
      organization: _organization,
      user: _user
    } do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      conn =
        conn
        |> get("/support")

      assert html_response(conn, 404) =~ "404"
    end

    test "redirects to support URL", %{conn: conn} do
      with_mock Front.Zendesk, new_ticket_location: fn -> "https://support-url.test" end do
        conn =
          conn
          |> get("/support")

        assert redirected_to(conn) == "https://support-url.test"
      end
    end
  end

  describe "GET pylon" do
    test "redirects to pylon support URL when feature is enabled", %{
      conn: conn,
      organization: organization
    } do
      org_id = organization.id

      with_mocks([
        {FeatureProvider, [],
         [
           feature_enabled?: fn
             :pylon_support, [param: ^org_id] -> true
             _, _ -> false
           end
         ]},
        {Front.Pylon, [],
         [
           new_ticket_location: fn %{email: email}, ^org_id ->
             assert is_binary(email) and email != ""
             {:ok, "https://pylon-support.test"}
           end
         ]}
      ]) do
        conn =
          conn
          |> get("/support/pylon")

        assert redirected_to(conn) == "https://pylon-support.test"
      end
    end

    test "shows alert when feature is disabled", %{conn: conn} do
      with_mocks([
        {FeatureProvider, [],
         [
           feature_enabled?: fn
             :pylon_support, [param: _org_id] -> false
             _, _ -> false
           end
         ]}
      ]) do
        conn =
          conn
          |> get("/support/pylon")

        assert redirected_to(conn) == "/"
        assert get_flash(conn, :alert) == "Pylon support is not enabled for this organization."
      end
    end

    test "shows alert when pylon URL generation fails", %{conn: conn} do
      with_mocks([
        {FeatureProvider, [],
         [
           feature_enabled?: fn
             :pylon_support, [param: _org_id] -> true
             _, _ -> false
           end
         ]},
        {Front.Pylon, [], [new_ticket_location: fn _, _ -> {:error, :missing_config} end]}
      ]) do
        conn =
          conn
          |> get("/support/pylon")

        assert redirected_to(conn) == "/"

        assert get_flash(conn, :alert) ==
                 "Unable to open Pylon support right now. Please try again."
      end
    end
  end

  describe "POST submit" do
    test "when the authorized user tries submitting the empty form, it shows the form errors", %{
      conn: conn
    } do
      conn =
        conn
        |> post("/support", %{})

      assert html_response(conn, 422) =~ "Select a topic first."
    end
  end
end
