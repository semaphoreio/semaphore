defmodule Front.Decorators.Header.Project do
  def project_description(""), do: ""
  def project_description(nil), do: ""
  def project_description(description), do: description

  def tab_class(conn, tab_path) do
    if is_tab_active?(conn, tab_path) do
      "tab tab--active"
    else
      "tab"
    end
  end

  def is_tab_active?(conn, tab_path) do
    conn_path_segments = conn.path_info
    tab_path_segments = String.split(tab_path, "/", trim: true)

    project_path_segments?(conn_path_segments) and
      project_path_segments?(tab_path_segments) and
      tab_segment(conn_path_segments) == tab_segment(tab_path_segments)
  end

  defp project_path_segments?(["projects" | rest]), do: not Enum.empty?(rest)
  defp project_path_segments?(_path_segments), do: false

  defp tab_segment(project_path_segments),
    do: project_path_segments |> Enum.drop(2) |> Enum.take(1)

  def workflows(conn, project_id) do
    params =
      struct!(Front.ProjectPage.Model.LoadParams,
        project_id: project_id,
        organization_id: conn.assigns.organization_id,
        user_id: conn.assigns.user_id,
        page_token: "",
        direction: "",
        user_page?: "false",
        ref_types: []
      )

    {:ok, model, _page_source} =
      Front.Tracing.track(conn.assigns.trace_id, "fetch_project_page_model", fn ->
        params |> Front.ProjectPage.Model.get(force_cold_boot: conn.params["force_cold_boot"])
      end)

    model.workflows
  end
end
