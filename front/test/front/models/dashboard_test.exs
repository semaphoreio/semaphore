defmodule Front.Models.Dashboard.Test do
  use ExUnit.Case

  alias Front.Models.Dashboard
  alias Support.Stubs.DB

  setup do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    dashboard = DB.first(:dashboards)
    organization = DB.first(:organizations)
    user = DB.first(:users)

    [
      dashboard: dashboard,
      user: user,
      organization: organization
    ]
  end

  describe ".find" do
    test "when the response is succesfull => it returns a dashboard model instance", %{
      dashboard: dashboard,
      user: user,
      organization: organization
    } do
      assert Dashboard.find(dashboard.id, organization.id, user.id) ==
               map_dashboard(dashboard.api_model)
    end
  end

  describe ".list" do
    test "when the response is succesfull => it returns a list of dashboard model instances", %{
      user: user,
      organization: organization,
      dashboard: dashboard
    } do
      assert Dashboard.list(user.id, organization.id) == [
               map_dashboard(dashboard.api_model)
             ]
    end
  end

  def map_dashboard(dashboard) do
    %Dashboard{
      id: dashboard.metadata.id,
      name: dashboard.metadata.name,
      title: dashboard.metadata.title,
      widgets:
        dashboard.spec.widgets
        |> Enum.map(fn widget ->
          %{
            "name" => widget.name,
            "type" => widget.type,
            "filters" => widget.filters
          }
        end)
    }
  end
end
