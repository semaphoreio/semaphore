defmodule Front.Browser.AccountTest do
  use FrontWeb.WallabyCase
  alias Support.Stubs

  setup %{session: session} do
    Stubs.init()
    Stubs.build_shared_factories()
    Stubs.PermissionPatrol.allow_everything()

    org = Stubs.DB.first(:organizations)
    org_id = Map.get(org, :id)

    resp = InternalApi.RBAC.ListAccessibleOrgsResponse.new(org_ids: [org_id])
    GrpcMock.stub(RBACMock, :list_accessible_orgs, resp)

    page_url = "http://me.localhost:4001/account/welcome/okta"

    {:ok, %{page_url: page_url, session: session, org_id: org_id}}
  end

  describe "Okta welcome page" do
    browser_test "it welcomes the customer to semaphore", %{page_url: page_url, session: session} do
      page = visit(session, page_url)

      assert_text(page, "Welcome")
    end

    browser_test "it asks the customer to connect to a git provider account", %{
      page_url: page_url,
      session: session
    } do
      page = visit(session, page_url)

      assert_text(page, "Please connect to your Git Provider account")
    end
  end
end
