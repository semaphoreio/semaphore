defmodule Front.Browser.OrganizationSettings.PreFlightChecksTest do
  use FrontWeb.WallabyCase
  alias Support.Stubs

  describe "organization init job defaults" do
    setup do
      %{id: user_id} = Stubs.User.create_default()
      %{id: org_id} = Stubs.Organization.create_default(restricted: false)

      Support.Stubs.Feature.enable_feature(org_id, :expose_cloud_agent_types)
      Support.Stubs.Feature.enable_feature(org_id, :permission_patrol)
      Support.Stubs.Feature.reset_org_machines(org_id)
      Support.Stubs.Feature.seed_machines()

      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.view",
        "organization.pre_flight_checks.view",
        "organization.pre_flight_checks.manage"
      ])

      {:ok, org_id: org_id, user_id: user_id}
    end

    browser_test "when user cannot view pre-flight checks then renders proper message",
                 %{session: session, org_id: org_id, user_id: user_id} do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.view"
      ])

      page = visit(session, "/pre_flight_checks")

      page
      |> assert_has(Query.text("Sorry, you can’t access Initialization job agent configuration."))
    end

    browser_test "when Linux & MAC machines are available then renders proper page without warning",
                 %{session: session, org_id: org_id} do
      Support.Stubs.Feature.enable_machine(org_id, "e1-standard-2")
      Support.Stubs.Feature.enable_machine(org_id, "a1-standard-4")

      page = visit(session, "/pre_flight_checks")

      page |> assert_has(Query.text("You can modify machine type and OS image"))
      page |> assert_has(Query.text("Linux Based Virtual Machine"))
      page |> assert_has(Query.text("Mac Based Virtual Machine"))
      page |> refute_has(Query.text("No agent types available."))
    end

    browser_test "when only Linux machines are available then renders proper page without warning",
                 %{session: session, org_id: org_id} do
      Support.Stubs.Feature.enable_machine(org_id, "e1-standard-2")

      page = visit(session, "/pre_flight_checks")

      page |> assert_has(Query.text("You can modify machine type and OS image"))
      page |> assert_has(Query.text("Linux Based Virtual Machine"))
      page |> refute_has(Query.text("Mac Based Virtual Machine"))
    end

    browser_test "when only MAC machines are available then renders proper page without warning",
                 %{session: session, org_id: org_id} do
      Support.Stubs.Feature.enable_machine(org_id, "a1-standard-4")

      page = visit(session, "/pre_flight_checks")

      page |> assert_has(Query.text("You can modify machine type and OS image"))
      page |> refute_has(Query.text("Linux Based Virtual Machine"))
      page |> assert_has(Query.text("Mac Based Virtual Machine"))
    end

    browser_test "when Linux & MAC machines are unavailable then renders proper page with warning",
                 %{session: session, org_id: _org_id} do
      page = visit(session, "/pre_flight_checks")

      page |> assert_has(Query.text("You can modify machine type and OS image"))
      page |> assert_has(Query.text("No agent types available."))
    end
  end

  describe "organization with pre-flight checks disabled" do
    setup do
      %{id: user_id} = Stubs.User.create_default()
      %{id: org_id} = Stubs.Organization.create_default(restricted: false)

      Support.Stubs.Feature.enable_feature(org_id, :permission_patrol)

      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.view",
        "organization.pre_flight_checks.view",
        "organization.pre_flight_checks.manage"
      ])

      {:ok, org_id: org_id}
    end

    browser_test "Initialization jobs tab does appear", %{session: session} do
      page = visit(session, "/settings")
      page |> assert_has(Query.text("Initialization jobs"))
    end

    browser_test "Pre-flight checks page renders proper message", %{session: session} do
      page = visit(session, "/pre_flight_checks")

      page
      |> refute_has(
        Query.text("Sorry, your organization doesn't have Pre-flight checks enabled.")
      )
      |> refute_has(Query.text("Pre-flight checks"))
    end
  end

  describe "organization with pre-flight checks enabled" do
    setup do
      %{id: user_id} = Stubs.User.create_default()
      %{id: org_id} = Stubs.Organization.create_default(restricted: true)
      Support.Stubs.Feature.set_org_defaults(org_id)

      Support.Stubs.Feature.enable_feature(org_id, :pre_flight_checks)
      Support.Stubs.Feature.enable_feature(org_id, :permission_patrol)

      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.view",
        "organization.pre_flight_checks.view",
        "organization.pre_flight_checks.manage"
      ])

      {:ok, org_id: Stubs.Organization.default_org_id()}
    end

    browser_test "initialization jobs tab does appear",
                 %{session: session} do
      page = visit(session, "/settings")
      page |> assert_has(Query.text("Initialization jobs"))
    end
  end
end
