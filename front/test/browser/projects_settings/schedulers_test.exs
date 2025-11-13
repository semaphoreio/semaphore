defmodule Front.Browser.ProjectSettings.SchedulersTest do
  use FrontWeb.WallabyCase

  describe "organization with JustRun enabled" do
    setup data do
      stubs = Support.Browser.ProjectSettings.create_project()
      periodic = Support.Stubs.Scheduler.create(stubs.project, stubs.user)
      context = data |> Map.merge(stubs) |> Map.merge(%{periodic: periodic})

      Support.Stubs.PermissionPatrol.allow_everything()

      {:ok, context}
    end

    browser_test "renders tasks' index page",
                 %{session: session, project: project, periodic: _periodic} do
      page = visit(session, "/projects/#{project.name}/schedulers")
      message = "Define tasks to trigger workflows according to your preference."
      page |> assert_has(Query.text(message))
    end

    browser_test "renders tasks' new page",
                 %{session: session, project: project, periodic: _periodic} do
      page = visit(session, "/projects/#{project.name}/schedulers/new")
      page |> assert_has(Query.text("New Task"))
    end

    browser_test "renders tasks' edit page",
                 %{session: session, project: project, periodic: periodic} do
      page = visit(session, "/projects/#{project.name}/schedulers/#{periodic.id}/edit")
      page |> assert_has(Query.text("Edit Task"))
    end
  end
end
