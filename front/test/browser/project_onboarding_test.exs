defmodule Front.Browser.ProjectOnboardingTest do
  use FrontWeb.WallabyCase
  alias Support.Stubs

  setup %{session: session} do
    Stubs.build_shared_factories()

    org = Stubs.DB.first(:organizations)
    org_id = Map.get(org, :id)

    {:ok, %{session: session, org_id: org_id}}
  end

  browser_test "bitbucket tab is shown by default", %{session: session} do
    page = session |> visit("/choose_repository")
    assert_text(page, "Bitbucket")
  end

  browser_test "bitbucket tab is hiiden if bitbucket feature is disabled", %{
    session: session,
    org_id: org_id
  } do
    Support.Stubs.Feature.disable_feature(org_id, :bitbucket)
    page = session |> visit("/choose_repository")
    refute has_text?(page, "Bitbucket")
  end
end
