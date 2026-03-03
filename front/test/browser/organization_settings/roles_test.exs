defmodule Front.Browser.OrganizationSettings.RolesTest do
  use FrontWeb.WallabyCase
  @moduletag :rbac_roles
  @feature_name :rbac__custom_roles

  setup do
    user = Support.Stubs.User.create_default()
    org = Support.Stubs.Organization.create_default(restricted: false)
    Support.Stubs.Feature.enable_feature(org.id, :permission_patrol)

    Support.Stubs.PermissionPatrol.add_permissions(org.id, user.id, [
      "organization.view",
      "organization.custom_roles.view",
      "organization.custom_roles.manage"
    ])

    on_exit(fn ->
      Support.Stubs.Feature.disable_feature(org.id, @feature_name)
    end)

    {:ok, %{user: user, org: org}}
  end

  describe "organization with custom roles disabled" do
    setup ctx do
      Support.Stubs.Feature.disable_feature(ctx.org.id, @feature_name)
      {:ok, ctx}
    end

    browser_test "access control roles tab does not appear", %{session: session} do
      page = visit(session, "/settings")
      page |> assert_has(Query.text("Roles"))
    end

    browser_test "access control roles page renders disabled 'New Role' button", %{
      session: session
    } do
      page = visit(session, "/roles")
      page |> assert_has(Query.button("New Role", count: 2))
      page |> assert_has(Query.css("button[disabled]", count: 2))
    end
  end

  describe "organization with custom roles as zero state" do
    setup ctx do
      Support.Stubs.Feature.zero_feature(ctx.org.id, @feature_name)
      {:ok, ctx}
    end

    browser_test "access control roles tab does appear", %{session: session} do
      page = visit(session, "/settings")
      page |> assert_has(Query.text("Roles"))
    end

    browser_test "access control roles page renders proper message", %{session: session} do
      page = visit(session, "/roles/organization/new")

      prompt_text = "Sorry, your organization does not have access to manage roles."

      page |> assert_has(Query.text(prompt_text))
    end
  end

  describe "organization with custom roles enabled" do
    setup ctx do
      Support.Stubs.Feature.enable_feature(ctx.org.id, @feature_name)
      {:ok, ctx}
    end

    browser_test "access control roles tab does appear", %{session: session} do
      page = visit(session, "/settings")
      page |> assert_has(Query.text("Roles"))
    end

    browser_test "access control roles page renders content", %{session: session} do
      page = visit(session, "/roles")

      page
      |> assert_has(Query.text("Manage roles at the organization level."))
      |> assert_has(Query.text("Manage roles available for your projects."))
    end
  end
end
