defmodule Front.Decorators.Header.WorkflowTest do
  use Front.TestCase
  alias Front.Decorators.Header.Workflow, as: WorkflowHeader

  def workflow_tabs do
    [
      "/workflows/69713874-2252-497f-b616-836d7b455427?pipeline_id",
      "/artifacts/workflows/69713874-2252-497f-b616-836d7b455427?project="
    ]
  end

  describe ".is_tab_active?" do
    test "it returns true when requested path and tab path match workflows path" do
      conn = %{request_path: "/workflows/69713874-2"}
      tab_path = "/workflows/something"

      assert WorkflowHeader.is_tab_active?(conn, tab_path)
    end

    test "it returns false when requested path and tab path don't match" do
      conn = %{request_path: "/artifacts/workflows/ee2e6241"}
      tab_path = "/workflows/11111"

      assert WorkflowHeader.is_tab_active?(conn, tab_path) == false
    end

    test "when artifacts path is requested, it's true for exactly one example value" do
      conn = %{request_path: "/artifacts/workflows/ee2e6241"}

      assert Enum.filter(workflow_tabs(), fn t -> WorkflowHeader.is_tab_active?(conn, t) end) == [
               "/artifacts/workflows/69713874-2252-497f-b616-836d7b455427?project="
             ]
    end

    test "when workflow path is requested, it's true for one example value" do
      conn = %{request_path: "/workflows/12121"}

      assert Enum.filter(workflow_tabs(), fn t -> WorkflowHeader.is_tab_active?(conn, t) end) == [
               "/workflows/69713874-2252-497f-b616-836d7b455427?pipeline_id"
             ]
    end
  end
end
