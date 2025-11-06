defmodule Front.Browser.ProjectSettings.Secrets do
  alias Wallaby.Query
  use FrontWeb.WallabyCase

  describe "organization with project level secrets disabled" do
    setup data do
      stubs = Support.Browser.ProjectSettings.create_project()
      context = Map.merge(data, stubs)

      Support.Stubs.Feature.disable_feature(stubs.org.id, :project_level_secrets)

      on_exit(fn ->
        Support.Stubs.Feature.enable_feature(stubs.org.id, :project_level_secrets)
      end)

      {:ok, context}
    end

    browser_test "project level secrets just forwarding to manage org secrets", %{
      session: session,
      project: project
    } do
      page = visit(session, "/projects/#{project.name}/settings/secrets")

      page
      |> refute_has(
        Query.text("Secrets authorized by your organization admins to be used on this project")
      )
    end
  end

  describe "organization with project level secrets enabled" do
    setup data do
      stubs = Support.Browser.ProjectSettings.create_project()
      context = Map.merge(data, stubs)

      Support.Stubs.Feature.enable_feature(context.org.id, :project_level_secrets)

      on_exit(fn ->
        Support.Stubs.Feature.disable_feature(stubs.org.id, :project_level_secrets)
      end)

      {:ok, context}
    end

    browser_test "without project secrets => secrets renders proper page",
                 %{
                   session: session,
                   project: project
                 } = ctx do
      Support.Stubs.Feature.enable_feature(ctx.org.id, :permission_patrol)
      Support.Stubs.PermissionPatrol.allow_everything(ctx.org.id, ctx.user.id)
      page = visit(session, "/projects/#{project.name}/settings/secrets")

      page
      |> assert_has(
        Query.text("Secrets authorized by your organization admins to be used on this project")
      )

      page
      |> assert_has(
        Query.text(
          "Secrets allow you to store and safely inject sensitive information into your jobs."
        )
      )

      org_secrets = get_org_secrets()

      Enum.each(org_secrets, fn secret ->
        page |> assert_has(Query.text(secret.name))
      end)
    end
  end

  defp get_org_secrets do
    Support.Stubs.Secret.find_list(:ORGANIZATION)
  end
end
