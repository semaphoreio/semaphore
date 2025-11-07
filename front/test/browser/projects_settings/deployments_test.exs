defmodule Front.Browser.ProjectSettings.DeploymentsTest do
  use FrontWeb.WallabyCase

  describe "organization with deployment targets disabled" do
    setup data do
      stubs = Support.Browser.ProjectSettings.create_project()
      context = Map.merge(data, stubs)

      Support.Stubs.Feature.disable_feature(stubs.org.id, :deployment_targets)

      on_exit(fn ->
        Support.Stubs.Feature.enable_feature(stubs.org.id, :deployment_targets)
      end)

      Support.Stubs.PermissionPatrol.allow_everything()

      {:ok, context}
    end

    browser_test "deployment targets tab does not appear", %{session: session, project: project} do
      page = visit(session, "/projects/#{project.name}/")
      page |> refute_has(Query.text("Deployments"))
    end

    browser_test "deployment targets page renders 404", %{session: session, project: project} do
      page = visit(session, "/projects/#{project.name}/deployments")
      page |> assert_has(Query.text("Page not found"))
    end
  end

  describe "organization with deployment targets as zero state" do
    setup data do
      stubs = Support.Browser.ProjectSettings.create_project()
      context = Map.merge(data, stubs)

      Support.Stubs.Feature.zero_feature(stubs.org.id, :deployment_targets)

      on_exit(fn ->
        Support.Stubs.Feature.enable_feature(stubs.org.id, :deployment_targets)
      end)

      Support.Stubs.PermissionPatrol.allow_everything()

      {:ok, context}
    end

    browser_test "deployment targets tab appears", %{session: session, project: project} = ctx do
      Support.Stubs.Feature.enable_feature(ctx.org.id, :permission_patrol)
      Support.Stubs.PermissionPatrol.allow_everything(ctx.org.id, ctx.user.id)
      page = visit(session, "/projects/#{project.name}/")
      page |> assert_has(Query.text("Deployments"))
    end

    browser_test "deployment targets page renders 404", %{session: session, project: project} do
      page = visit(session, "/projects/#{project.name}/deployments")

      page
      |> assert_has(
        Query.text("Sorry, your organization does not have access to Deployment Targets.")
      )
    end
  end

  describe "organization with deployment targets enabled" do
    setup data do
      stubs = Support.Browser.ProjectSettings.create_project()
      context = Map.merge(data, stubs)

      Support.Stubs.Feature.enable_feature(stubs.org.id, :deployment_targets)

      Support.Stubs.PermissionPatrol.allow_everything()

      {:ok, context}
    end

    browser_test "deployment targets tab does appear",
                 %{session: session, project: project} = ctx do
      Support.Stubs.Feature.enable_feature(ctx.org.id, :permission_patrol)
      Support.Stubs.PermissionPatrol.allow_everything(ctx.org.id, ctx.user.id)
      page = visit(session, "/projects/#{project.name}/")
      page |> assert_has(Query.text("Deployments"))
    end

    browser_test "deployment targets page renders proper page", %{
      session: session,
      project: project
    } do
      page = visit(session, "/projects/#{project.name}/deployments")
      page |> assert_has(Query.text("Deployment Targets", count: 3))
      page |> assert_has(Query.text("Connect your servers and model the interaction"))
    end
  end
end
