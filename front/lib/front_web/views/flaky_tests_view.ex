defmodule FrontWeb.FlakyTestsView do
  use FrontWeb, :view

  def json_config(conn, project) do
    config(conn, project)
    |> Poison.encode!()
  end

  # /projects/<%= @project.id %>/flaky_tests
  def config(conn, project) do
    %{
      baseURL: flaky_tests_index_path(conn, :index, project.name, []),
      flakyURL: flaky_tests_flaky_list_path(conn, :flaky_tests, project.name),
      flakyDetailsURL: flaky_tests_details_path(conn, :flaky_test_details, project.name),
      flakyDisruptionOccurencesURL:
        flaky_tests_disruptions_path(conn, :flaky_test_disruptions, project.name),
      flakyHistoryURL: flaky_tests_flaky_history_path(conn, :flaky_history, project.name),
      disruptionHistoryURL:
        flaky_tests_disruption_history_path(conn, :disruption_history, project.name),
      filtersURL: flaky_tests_filters_path(conn, :filters, project.name),
      createFilterURL: flaky_tests_create_filter_path(conn, :create_filter, project.name),
      removeFilterURL: flaky_tests_remove_filter_path(conn, :remove_filter, project.name),
      updateFilterURL: flaky_tests_update_filter_path(conn, :update_filter, project.name),
      webhookSettingsURL: flaky_tests_webhook_settings_path(conn, :webhook_settings, project.name)
    }
  end

  def render("flaky_tests.json", %{flaky_tests: data}) do
    data
  end

  def render("flaky_history.json", %{historical: data}) do
    data
  end

  def render("disruptions_history.json", %{historical: data}) do
    data
  end

  def render("filters.json", %{filters: data}) do
    data
    |> Enum.sort(fn f1, f2 -> f1.inserted_at.seconds < f2.inserted_at.seconds end)
  end

  def render("filter.json", %{filter: data}) do
    data
  end
end
