defmodule Support.Browser.ProjectSettings do
  use Wallaby.DSL

  alias Support.Stubs
  use Wallaby.DSL

  def create_project do
    Stubs.init()
    Stubs.build_shared_factories()

    user = Stubs.User.default()
    org = Stubs.Organization.default()
    project = Stubs.DB.first(:projects)

    %{user: user, org: org, project: project}
  end
end
