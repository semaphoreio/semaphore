defmodule FrontWeb.PeopleViewTest do
  use FrontWeb.ConnCase

  alias FrontWeb.PeopleView

  setup %{conn: conn} do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    organization = Support.Stubs.Organization.default()
    user = Support.Stubs.User.default()

    edition = Application.get_env(:front, :edition)
    enforced = Application.get_env(:front, :enforce_service_account_owner?)

    on_exit(fn ->
      Application.put_env(:front, :edition, edition)
      Application.put_env(:front, :enforce_service_account_owner?, enforced)
    end)

    conn =
      conn
      |> Plug.Conn.assign(:organization_id, organization.id)
      |> Plug.Conn.assign(:user_id, user.id)
      |> Plug.Conn.assign(:permissions, %{
        "organization.service_accounts.view" => true,
        "organization.service_accounts.manage" => true
      })

    [conn: conn]
  end

  describe "service_accounts_config/1" do
    test "shows ownership without claiming it is enforced while the rule is off", %{conn: conn} do
      Application.put_env(:front, :edition, nil)
      Application.put_env(:front, :enforce_service_account_owner?, false)

      config = PeopleView.service_accounts_config(conn)

      assert config.show_ownership
      refute config.ownership_enforced
    end

    test "says ownership is enforced once the rule is on", %{conn: conn} do
      Application.put_env(:front, :edition, nil)
      Application.put_env(:front, :enforce_service_account_owner?, true)

      config = PeopleView.service_accounts_config(conn)

      assert config.show_ownership
      assert config.ownership_enforced
    end

    test "says nothing about ownership on a self-hosted install", %{conn: conn} do
      Application.put_env(:front, :edition, "ce")
      Application.put_env(:front, :enforce_service_account_owner?, true)

      config = PeopleView.service_accounts_config(conn)

      refute config.show_ownership
      refute config.ownership_enforced
    end
  end
end
