defmodule FrontWeb.Insights.MetricsView do
  use FrontWeb, :view

  def render("pipeline_performance.json", %{metrics: metrics}) do
    metrics
  end

  def render("pipeline_reliability.json", %{metrics: metrics}) do
    metrics
  end

  def render("pipeline_frequency.json", %{metrics: metrics}) do
    metrics
  end

  def render("summary.json", %{
        performance: performance,
        frequency: frequency,
        reliability: reliability,
        project: project
      }) do
    %{
      performance: performance,
      frequency: frequency,
      reliability: reliability,
      project: project
    }
  end

  def render("insights_project_settings.json", %{settings: settings}) do
    settings
  end
end
