defmodule FrontWeb.Insights.MetricsControllerTest do
  use FrontWeb.ConnCase
  doctest FrontWeb.Insights.MetricsController
  alias Support.Stubs.DB

  @moduletag :insights
  @moduletag :json_api

  setup %{conn: conn} do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    project = DB.first(:projects)

    %{project: project, conn: conn}
  end

  describe "GET pipeline performance metrics" do
    test "returns 200", %{conn: conn, project: project} do
      response =
        conn
        |> get("/projects/#{project.name}/insights/metrics/pipeline_performance")
        |> json_response(200)

      assert length(response["all"]) == 30
      assert length(response["passed"]) == 30
      assert length(response["failed"]) == 30
    end
  end

  describe "GET pipeline frequency metrics" do
    test "returns 200", %{conn: conn, project: project} do
      response =
        conn
        |> get("/projects/#{project.name}/insights/metrics/pipeline_frequency")
        |> json_response(200)

      assert length(response["metrics"]) == 30
    end
  end

  describe "GET pipeline reliability metrics" do
    test "returns 200", %{conn: conn, project: project} do
      response =
        conn
        |> get("/projects/#{project.name}/insights/metrics/pipeline_reliability")
        |> json_response(200)

      assert length(response["metrics"]) == 30
    end
  end

  describe "GET pipeline metrics summary" do
    test "returns 200", %{conn: conn, project: project} do
      response =
        conn
        |> get("/projects/#{project.name}/insights/metrics/summary")
        |> json_response(200)

      assert length(get_in(response, ["performance", "all"])) == 1
      assert length(get_in(response, ["performance", "passed"])) == 1
      assert length(get_in(response, ["performance", "failed"])) == 1
      assert length(get_in(response, ["reliability", "metrics"])) == 1
      assert length(get_in(response, ["frequency", "metrics"])) == 1

      assert %{
               "last_successful_run_at" => _,
               "mean_time_to_recovery" => _
             } = get_in(response, ["project"])
    end
  end
end
