defmodule PipelinesAPI.SuperjerryClient.RequestFormatterTest do
  use ExUnit.Case, async: true

  alias PipelinesAPI.SuperjerryClient.RequestFormatter, as: RF
  alias InternalApi.Superjerry.{ListFlakyTestsRequest, FlakyTestDetailsRequest}

  test "form_list_flaky_tests_request maps org/project/pagination/sort" do
    assert {:ok, %ListFlakyTestsRequest{} = req} =
             RF.form_list_flaky_tests_request(%{
               "org_id" => "o",
               "project_id" => "p",
               "page" => "2",
               "page_size" => "10",
               "sort_field" => "pass_rate",
               "sort_dir" => "asc"
             })

    assert req.org_id == "o" and req.project_id == "p"
    assert req.pagination.page == 2 and req.pagination.page_size == 10
    assert req.sort.name == "pass_rate" and req.sort.dir == 0
  end

  test "filters: structured params become an @key:value string in allow-list order" do
    assert {:ok, %ListFlakyTestsRequest{filters: f}} =
             RF.form_list_flaky_tests_request(%{
               "org_id" => "o",
               "project_id" => "p",
               "branch" => "main",
               "resolved" => "false",
               "pass_rate" => ">=80",
               "label" => "flaky,slow",
               "bogus" => "drop-me"
             })

    assert f =~ "@git.branch:main"
    assert f =~ "@is.resolved:false"
    assert f =~ "@metric.pass_rate:>=80"
    assert f =~ "@label:\"flaky,slow\""
    refute f =~ "bogus"
  end

  test "values with spaces are double-quoted" do
    assert {:ok, %FlakyTestDetailsRequest{filters: f}} =
             RF.form_flaky_test_details_request(%{
               "org_id" => "o",
               "project_id" => "p",
               "test_id" => "t",
               "branch" => "feature branch"
             })

    assert f =~ ~s(@git.branch:"feature branch")
  end
end
