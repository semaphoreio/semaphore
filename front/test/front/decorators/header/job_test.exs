defmodule Front.Decorators.Header.JobTest do
  use Front.TestCase
  alias Front.Decorators.Header.Job, as: JobHeader

  def job_tabs do
    [
      "/jobs/69713874-2252-497f-b616-836d7b455427?pipeline_id",
      "/test_results/jobs/69713874-2252-497f-b616-836d7b455427",
      "/jobs/69713874-2252-497f-b616-836d7b455427/summary",
      "/artifacts/jobs/69713874-2252-497f-b616-836d7b455427?project="
    ]
  end

  describe ".is_tab_active?" do
    test "it returns true when requested path and tab path match jobs path" do
      conn = %{request_path: "/jobs/69713874-2"}
      tab_path = "/jobs/something"

      assert JobHeader.is_tab_active?(conn, tab_path)
    end

    test "it returns false when requested path and tab path don't match" do
      conn = %{request_path: "/artifacts/jobs/ee2e6241"}
      tab_path = "/jobs/11111"

      assert JobHeader.is_tab_active?(conn, tab_path) == false
    end

    test "when artifacts path is requested, it's true for exactly one example value" do
      conn = %{request_path: "/artifacts/jobs/ee2e6241"}

      assert Enum.filter(job_tabs(), fn t -> JobHeader.is_tab_active?(conn, t) end) == [
               "/artifacts/jobs/69713874-2252-497f-b616-836d7b455427?project="
             ]
    end

    test "when job path is requested, it's true for one example value" do
      conn = %{request_path: "/jobs/12121"}

      assert Enum.filter(job_tabs(), fn t -> JobHeader.is_tab_active?(conn, t) end) == [
               "/jobs/69713874-2252-497f-b616-836d7b455427?pipeline_id"
             ]
    end

    test "when test results path is requested, its true for one value" do
      conn = %{request_path: "/test_results/jobs/abc"}

      assert Enum.filter(job_tabs(), fn t -> JobHeader.is_tab_active?(conn, t) end) == [
               "/test_results/jobs/69713874-2252-497f-b616-836d7b455427"
             ]
    end

    test "when new test results path is requested, its true for one value" do
      conn = %{request_path: "/jobs/1234/summary"}

      assert Enum.filter(job_tabs(), fn t -> JobHeader.is_tab_active?(conn, t) end) == [
               "/jobs/69713874-2252-497f-b616-836d7b455427/summary"
             ]
    end
  end
end
