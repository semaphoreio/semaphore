defmodule E2E.UI.ExampleUserTest do
  use E2E.UI.UserTestCase

  describe "Dashboard" do
    test "User can view dashboard elements", %{session: session, organization: organization, base_domain: base_domain} do
      # Test starts with already logged-in user because of UserTestCase setup
      
      # Navigate to dashboard
      dashboard_url = "https://#{organization}.#{base_domain}/dashboard"
      
      session
      |> Wallaby.Browser.visit(dashboard_url)
      |> Wallaby.Browser.assert_has(Wallaby.Query.css(".dashboard-content"))
      
      # Take a screenshot of dashboard
      Wallaby.Browser.take_screenshot(session)
    end
  end
end
