# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Front.Browser.ProjectSettings.PreFlightChecksTest do
  use FrontWeb.WallabyCase

  describe "organization with pre-flight checks disabled" do
    setup data do
      stubs = Support.Browser.ProjectSettings.create_project()
      context = Map.merge(data, stubs)

      Support.Stubs.PermissionPatrol.allow_everything()

      {:ok, context}
    end

    browser_test "Pre-flight checks tab does not appear", %{session: session, project: project} do
      page = visit(session, "/projects/#{project.name}/settings/general")
      page |> refute_has(Query.text("Pre-flight checks"))
    end

    browser_test "Pre-flight checks page renders proper message", %{
      session: session,
      project: project
    } do
      page = visit(session, "/projects/#{project.name}/settings/pre_flight_checks")
      message = "Sorry, your organization doesn't have Pre-flight checks enabled."
      page |> assert_has(Query.text(message))
    end
  end

  describe "organization with pre-flight checks enabled" do
    setup data do
      stubs = Support.Browser.ProjectSettings.create_project()
      context = Map.merge(data, stubs) |> Map.put(:org_id, stubs.org.id)

      Support.Stubs.Feature.enable_feature(stubs.org.id, :pre_flight_checks)
      Support.Stubs.PermissionPatrol.allow_everything(context.org.id, context.user.id)
      Support.Stubs.Feature.reset_org_machines(stubs.org.id)
      Support.Stubs.Feature.seed_machines()

      {:ok, context}
    end

    browser_test "Pre-flight checks tab does appear", %{session: session, project: project} do
      page = visit(session, "/projects/#{project.name}/settings/general")
      page |> assert_has(Query.text("Pre-flight checks"))
    end

    browser_test "Pre-flight checks page renders proper page", %{
      session: session,
      project: project
    } do
      page = visit(session, "/projects/#{project.name}/settings/pre_flight_checks")

      message =
        "Define commands and used secrets to configure custom security measures before running the pipeline."

      page |> assert_has(Query.text(message))
    end

    browser_test "when Linux & MAC machines are available then renders proper page without warning",
                 %{session: session, org_id: org_id, project: project} do
      Support.Stubs.Feature.enable_machine(org_id, "e1-standard-2")
      Support.Stubs.Feature.enable_machine(org_id, "a1-standard-4")

      page =
        visit(session, "/projects/#{project.name}/settings/pre_flight_checks")
        |> click(Query.checkbox("Override default agent configuration"))

      page |> assert_has(Query.text("Define commands and used secrets"))
      page |> assert_has(Query.text("Linux Based Virtual Machine"))
      page |> assert_has(Query.text("Mac Based Virtual Machine"))
      page |> refute_has(Query.text("No agent types available."))
    end

    browser_test "when only Linux machines are available then renders proper page without warning",
                 %{session: session, org_id: org_id, project: project} do
      Support.Stubs.Feature.enable_machine(org_id, "e1-standard-2")

      page =
        visit(session, "/projects/#{project.name}/settings/pre_flight_checks")
        |> click(Query.checkbox("Override default agent configuration"))

      page |> assert_has(Query.text("Define commands and used secrets"))
      page |> assert_has(Query.text("Linux Based Virtual Machine"))
      page |> refute_has(Query.text("Mac Based Virtual Machine"))
    end

    browser_test "when only MAC machines are available then renders proper page without warning",
                 %{session: session, org_id: org_id, project: project} do
      Support.Stubs.Feature.enable_machine(org_id, "a1-standard-4")

      page =
        visit(session, "/projects/#{project.name}/settings/pre_flight_checks")
        |> click(Query.checkbox("Override default agent configuration"))

      page |> assert_has(Query.text("Define commands and used secrets"))
      page |> refute_has(Query.text("Linux Based Virtual Machine"))
      page |> assert_has(Query.text("Mac Based Virtual Machine"))
    end

    browser_test "when Linux & MAC machines are unavailable then renders proper page with warning",
                 %{session: session, org_id: _org_id, project: project} do
      page = visit(session, "/projects/#{project.name}/settings/pre_flight_checks")

      page |> assert_has(Query.text("Define commands and used secrets"))
      page |> assert_has(Query.text("No agent types available."))
    end
  end

  describe "organization with pre-flight checks enabled and no agent types" do
    setup data do
      stubs = Support.Browser.ProjectSettings.create_project()
      context = Map.merge(data, stubs) |> Map.put(:org_id, stubs.org.id)

      Support.Stubs.Feature.enable_feature(stubs.org.id, :pre_flight_checks)
      Support.Stubs.PermissionPatrol.allow_everything(context.org.id, context.user.id)
      Support.Stubs.Feature.reset_org_machines(stubs.org.id)
      Support.Stubs.Feature.seed_machines()

      {:ok, context}
    end

    browser_test "Pre-flight checks tab does appear", %{session: session, project: project} do
      page = visit(session, "/projects/#{project.name}/settings/general")
      page |> assert_has(Query.text("Pre-flight checks"))
    end

    browser_test "Pre-flight checks page renders proper page", %{
      session: session,
      project: project
    } do
      page = visit(session, "/projects/#{project.name}/settings/pre_flight_checks")

      page
      |> assert_has(
        Query.text(
          "Define commands and used secrets to configure custom security measures before running the pipeline."
        )
      )

      page |> assert_has(Query.text("No agent types available."))
    end
  end
end
