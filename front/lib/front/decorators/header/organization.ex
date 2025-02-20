defmodule Front.Decorators.Header.Organization do
  def tab_class(conn, tab_path) do
    if is_tab_active?(conn, tab_path) do
      "tab tab--active"
    else
      "tab"
    end
  end

  def is_tab_active?(conn, tab_path) do
    [
      "get_started",
      "agents",
      "activity",
      "audit",
      "people",
      "projects",
      "settings",
      "billing",
      "self_hosted_agents"
    ]
    |> Enum.any?(fn page ->
      is_tab_active?(conn, tab_path, page)
    end)
  end

  def is_tab_active?(conn, tab_path, "settings") do
    is_settings_path?(tab_path) and is_settings_path?(conn.request_path)
  end

  def is_tab_active?(conn, tab_path, tab_name) do
    tab_path =~ tab_name and conn.request_path =~ tab_name
  end

  defp is_settings_path?(path),
    do: path =~ ~r(secrets|notifications|settings|pre_flight_checks|roles)
end
