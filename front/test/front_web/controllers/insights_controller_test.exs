defmodule FrontWeb.InsightsControllerTest do
  use FrontWeb.ConnCase
  doctest FrontWeb.InsightsController
  alias Support.Stubs.DB

  @moduletag :insights

  setup %{conn: conn} do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    project = DB.first(:projects)

    %{project: project, conn: conn}
  end

  describe "GET project performance metrics" do
    test "returns 200", %{conn: conn, project: project} do
      response =
        conn
        |> get("/projects/#{project.name}/insights")
        |> html_response(200)

      # DOM elements in place?
      assert response =~ "<span>Insights</span>"
      assert response =~ "id=\"insights-app\""

      # JavaScript configuration in place?
      assert response =~ "\"defaultBranchName\":"
      assert response =~ "\"pipelinePerformanceUrl\":"
      assert response =~ "\"pipelineFrequencyUrl\":"
      assert response =~ "\"pipelineReliabilityUrl\":"
      assert response =~ "\"summaryUrl\":"
    end
  end
end
