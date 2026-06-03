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

  test "value containing embedded double-quote cannot inject a second @key clause" do
    # A raw value like: main" @is.resolved:false x="
    # Without hardening this would produce: @git.branch:main" @is.resolved:false x="
    # which the Superjerry parser (no backslash escape) would read as two separate
    # clauses — @git.branch:main and @is.resolved:false.
    # encode_filter_value strips embedded " before quoting, so the whole value
    # lands inside a single quoted token: @git.branch:"main @is.resolved:false x="
    # The parser only starts a new key on @ while NOT inQuote, so the embedded
    # text stays inside the current value — no second clause is produced.
    assert {:ok, %ListFlakyTestsRequest{filters: f}} =
             RF.form_list_flaky_tests_request(%{
               "org_id" => "o",
               "project_id" => "p",
               "branch" => ~s(main" @is.resolved:false x=")
             })

    # The entire output must be the single safe quoted clause — if injection
    # had succeeded there would be content after the closing quote.
    assert f == ~s(@git.branch:"main @is.resolved:false x=")
  end

  test "value containing @ and : is quoted and cannot open a new clause" do
    # The parser starts a new key only when it sees @ outside a quoted value.
    # Always-quoted encoding keeps @ inside the value token.
    assert {:ok, %ListFlakyTestsRequest{filters: f}} =
             RF.form_list_flaky_tests_request(%{
               "org_id" => "o",
               "project_id" => "p",
               "branch" => "main @is.resolved:false"
             })

    assert f == ~s(@git.branch:"main @is.resolved:false")
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
end
