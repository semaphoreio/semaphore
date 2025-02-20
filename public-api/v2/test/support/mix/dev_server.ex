defmodule Mix.Tasks.Dev.Server do
  use Mix.Task

  def run(_) do
    Mix.Task.run("app.start")

    Support.Stubs.build_shared_factories()

    org_id = Support.Stubs.Organization.default_org_id()
    user_id = Support.Stubs.User.default_user_id()

    Support.Stubs.PermissionPatrol.add_all_permissions(org_id, user_id)
  end
end
