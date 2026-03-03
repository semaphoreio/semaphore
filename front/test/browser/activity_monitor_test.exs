defmodule Front.Browser.ActivityMonitorTest do
  use FrontWeb.WallabyCase

  setup %{session: session} do
    FrontWeb.Plugs.Development.ActivityMonitor.stub()
    user = Support.Stubs.User.create_default()
    org = Support.Stubs.Organization.create_default()
    Support.Stubs.Feature.enable_feature(org.id, :permission_patrol)

    Support.Stubs.PermissionPatrol.add_permissions(org.id, user.id, [
      "organization.view",
      "organization.activity_monitor.view"
    ])

    page = session |> visit("/activity")

    {:ok, %{page: page}}
  end

  browser_test "active pipelines are displayed on the activity monitor page", %{page: page} do
    FrontWeb.Plugs.Development.ActivityMonitor.running_pipelines()
    |> Enum.each(fn p ->
      assert_text(page, p.commit_message)
    end)
  end

  browser_test "queuing pipelines are displayed on the activity monitor page", %{page: page} do
    assert_text(page, "Lobby")
    assert_text(page, "(1)")
  end

  browser_test "usage gauge for machines are presented on the activity monitor", %{page: page} do
    assert_text(page, "e1-standard-2")
    assert_text(page, "4/8")
  end
end
