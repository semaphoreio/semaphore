defmodule Front.Decorators.Header.ProjecTest do
  use Front.TestCase
  alias Front.Decorators.Header.Project, as: ProjectHeader

  def project_tabs do
    # activities tab is available on /projects/:id path
    [
      "/artifacts/projects/111",
      "/projects/111/schedulers",
      "/projects/pipeline-schedulers/people",
      "/projects/111/people",
      "/projects/111/settings/general",
      "projects/front/settings/notifications",
      "projects/battle-artifacts/schedulers",
      "/projects/333",
      "/projects/333/",
      "/projects/insights/insights"
    ]
  end

  describe ".is_tab_active?" do
    test "it returns true when requested path and tab path match project activity path" do
      conn = conn_from("/projects/ee2e6241")
      tab_path = "/projects/project-name"

      assert ProjectHeader.is_tab_active?(conn, tab_path)
    end

    test "it returns false when requested path and tab path don't match" do
      conn = conn_from("/artifacts/projects/ee2e6241")
      tab_path = "/projects/project-name/people"

      assert ProjectHeader.is_tab_active?(conn, tab_path) == false
    end

    test "when /projects path is requested, it's false for every example value" do
      conn = conn_from("/projects/")

      assert Enum.filter(project_tabs(), fn t -> ProjectHeader.is_tab_active?(conn, t) end) == []
    end

    test "when schedulers path is requested, it's true for two example values" do
      conn = conn_from("/projects/clean-code-javascript/schedulers")

      assert Enum.filter(project_tabs(), fn t -> ProjectHeader.is_tab_active?(conn, t) end) == [
               "/projects/111/schedulers",
               "projects/battle-artifacts/schedulers"
             ]
    end

    test "when people path is requested, it's true for two project people example values" do
      conn = conn_from("/projects/clean-code-javascript/people")

      assert Enum.filter(project_tabs(), fn t -> ProjectHeader.is_tab_active?(conn, t) end) == [
               "/projects/pipeline-schedulers/people",
               "/projects/111/people"
             ]
    end

    test "when project settings path is requested, it's true for two project settings example values" do
      conn = conn_from("/projects/clean-code-javascript/settings/general")

      assert Enum.filter(project_tabs(), fn t -> ProjectHeader.is_tab_active?(conn, t) end) == [
               "/projects/111/settings/general",
               "projects/front/settings/notifications"
             ]
    end

    test "when activity path is requested, it's true for two example values" do
      conn = conn_from("/projects/clean-code-javascript")

      assert Enum.filter(project_tabs(), fn t -> ProjectHeader.is_tab_active?(conn, t) end) ==
               ["/projects/333", "/projects/333/"]
    end

    test "when insights path is requested, it should be true for insights" do
      assert is_path_active?("/projects/insights/insights", "/projects/insights/insights")
      refute is_path_active?("/projects/insights/insights", "/projects/insights/settings")

      refute is_path_active?(
               "/projects/some-project-name/insights",
               "/projects/insights/settings"
             )
    end
  end

  defp is_path_active?(path, name) do
    conn = conn_from(path)

    ProjectHeader.is_tab_active?(conn, name)
  end

  defp conn_from(request_path) do
    %{
      request_path: request_path,
      path_info: String.split(request_path, "/", trim: true)
    }
  end
end
