defmodule FrontWeb.Insights.DashboardsView do
  use FrontWeb, :view

  def render("index.json", %{dashboards: dashboards}) do
    dashboards
  end

  def render("show.json", %{dashboard: dashboard}) do
    dashboard
  end
end
