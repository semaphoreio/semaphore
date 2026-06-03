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

    assert f =~ ~s(@git.branch:"main")
    assert f =~ ~s(@is.resolved:"false")
    assert f =~ ~s(@metric.pass_rate:">=80")
    assert f =~ ~s(@label:"flaky,slow")
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

  test "value containing embedded double-quote and @ has both stripped" do
    # Input: main" @is.resolved:false x="
    # Both " and @ are injection vectors and are stripped before quoting.
    # " without stripping would close the quote early; @ without stripping
    # starts a new clause regardless of quote state (confirmed in Go parser).
    # After stripping both: main is.resolved:false x=
    assert {:ok, %ListFlakyTestsRequest{filters: f}} =
             RF.form_list_flaky_tests_request(%{
               "org_id" => "o",
               "project_id" => "p",
               "branch" => ~s(main" @is.resolved:false x=")
             })

    assert f == ~s(@git.branch:"main is.resolved:false x=")
    refute String.contains?(f, "@is.resolved")
  end

  test "value containing @ has @ stripped so no second clause can be injected" do
    # The Superjerry Go parser's @ case checks !inKey but NOT !inQuote, so a
    # bare @ inside a quoted value DOES start a new filter clause. We strip @
    # from the value before quoting to prevent this.
    # Input branch="main @is.resolved:false" would inject a second clause
    # without stripping. After stripping, it becomes "main is.resolved:false".
    assert {:ok, %ListFlakyTestsRequest{filters: f}} =
             RF.form_list_flaky_tests_request(%{
               "org_id" => "o",
               "project_id" => "p",
               "branch" => "main @is.resolved:false"
             })

    assert f == ~s(@git.branch:"main is.resolved:false")
    refute String.contains?(f, "@is.resolved")
  end

  test "value containing a space is quoted so the parser sees one token" do
    assert {:ok, %ListFlakyTestsRequest{filters: f}} =
             RF.form_list_flaky_tests_request(%{
               "org_id" => "o",
               "project_id" => "p",
               "test_name" => "My Test Case"
             })

    assert f == ~s(@test.name:"My Test Case")
  end

  test "page_size is capped at 100 regardless of caller input" do
    assert {:ok, %ListFlakyTestsRequest{} = req} =
             RF.form_list_flaky_tests_request(%{
               "org_id" => "o",
               "project_id" => "p",
               "page_size" => "100000"
             })

    assert req.pagination.page_size == 100
  end
end
