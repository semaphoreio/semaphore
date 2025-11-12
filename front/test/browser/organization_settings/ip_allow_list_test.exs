defmodule Front.Browser.OrganizationSettings.IpAllowListTest do
  use FrontWeb.WallabyCase
  alias Support.Stubs

  describe "non-restricted org" do
    setup %{session: session} do
      Stubs.PermissionPatrol.allow_everything()

      Stubs.User.create_default()
      Stubs.Organization.create_default(restricted: false)

      page = visit(session, "/settings")

      {:ok, %{page: page}}
    end

    browser_test "IP allow list tab does not appear", %{page: page} do
      page |> refute_has(Query.text("IP Allow List"))
    end
  end

  describe "restricted org" do
    setup %{session: session} do
      Stubs.PermissionPatrol.allow_everything()

      Stubs.User.create_default()
      Stubs.Organization.create_default(restricted: true)

      page = visit(session, "/settings")

      {:ok, %{page: page}}
    end

    browser_test "IP allow list tab does not appear", %{page: page} do
      page |> refute_has(Query.text("IP Allow List"))
    end
  end
end
