defmodule Front.Browser.ProjectDeploymentsTest do
  use FrontWeb.WallabyCase

  describe "organization with deployment targets disabled" do
    setup data do
      stubs = Support.Browser.ProjectSettings.create_project()
      context = Map.merge(data, stubs)

      Support.Stubs.PermissionPatrol.allow_everything()

      Support.Stubs.Feature.disable_feature(stubs.org.id, :deployment_targets)

      {:ok, context}
    end

    browser_test "Deployments tab does not appear", %{session: session, project: project} do
      page = visit(session, "/projects/#{project.name}")
      page |> refute_has(Query.text("Deployments"))
    end

    browser_test "Deployments endpoint returns 404", %{session: session, project: project} do
      page = visit(session, "/projects/#{project.name}/deployments")
      page |> assert_has(Query.text("Page not found"))
    end
  end

  describe "organization with deployment targets enabled" do
    setup data do
      stubs = Support.Browser.ProjectSettings.create_project()
      context = Map.merge(data, stubs)

      Support.Stubs.PermissionPatrol.allow_everything()

      Support.Stubs.Feature.enable_feature(stubs.org.id, :deployment_targets)

      {:ok, context}
    end

    browser_test "Deployments tab does appear", %{session: session, project: project} = ctx do
      Support.Stubs.Feature.enable_feature(ctx.org.id, :permission_patrol)
      Support.Stubs.PermissionPatrol.allow_everything(ctx.org.id, ctx.user.id)
      page = visit(session, "/projects/#{project.name}")
      page |> assert_has(Query.text("Deployments"))
    end

    browser_test "when permissions are granted then deployments indexs renders proper page",
                 %{session: session, project: project} do
      page = visit(session, "/projects/#{project.name}/deployments")

      message =
        "Connect your servers and model the interaction " <>
          "between your continuous delivery pipeline and your deployment environments."

      page |> assert_has(Query.text(message))
    end

    browser_test "when permissions are not granted then Deployments index renders proper message",
                 %{session: session, project: project} do
      org = Support.Stubs.Organization.default()
      user = Support.Stubs.User.default()

      Support.Stubs.PermissionPatrol.remove_all_permissions()

      Support.Stubs.PermissionPatrol.allow_everything_except(org.id, user.id, [
        "project.deployment_targets.view",
        "project.deployment_targets.manage"
      ])

      page = visit(session, "/projects/#{project.name}/deployments")
      page |> assert_has(Query.text("Sorry, you can’t access Deployment Targets."))
    end

    browser_test "when permissions are not granted then Deployments new renders proper message",
                 %{session: session, project: project} do
      org = Support.Stubs.Organization.default()
      user = Support.Stubs.User.default()

      Support.Stubs.PermissionPatrol.remove_all_permissions()

      Support.Stubs.PermissionPatrol.allow_everything_except(
        org.id,
        user.id,
        "project.deployment_targets.manage"
      )

      page = visit(session, "/projects/#{project.name}/deployments/new")
      page |> assert_has(Query.text("Sorry, you can’t modify Deployment Targets."))
    end
  end
end
