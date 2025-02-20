defmodule FrontWeb.InsightsView do
  use FrontWeb, :view

  def json_config(conn, project, default_branch_name) do
    config(conn, project, default_branch_name)
    |> Poison.encode!()
  end

  # /projects/<%= @project.id %>/branches
  def config(conn, project, default_branch_name) do
    %{
      baseUrl: insights_index_path(conn, :index, project.name, []),
      pipelinePerformanceUrl:
        insights_metrics_path(conn, :index, project.name, :pipeline_performance),
      pipelineFrequencyUrl:
        insights_metrics_path(conn, :index, project.name, :pipeline_frequency),
      pipelineReliabilityUrl:
        insights_metrics_path(conn, :index, project.name, :pipeline_reliability),
      summaryUrl: insights_metrics_path(conn, :index, project.name, :summary),
      insightsSettingsUrl:
        insights_metrics_path(conn, :get_insights_project_settings, project.id),
      defaultBranchName: default_branch_name,
      dashboardsUrl: insights_dashboards_path(conn, :index, project.name),
      availableDatesUrl: insights_metrics_path(conn, :available_metrics_dates, project.name)
    }
  end
end
