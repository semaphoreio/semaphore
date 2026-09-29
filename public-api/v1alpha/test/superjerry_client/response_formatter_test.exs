defmodule PipelinesAPI.SuperjerryClient.ResponseFormatterTest do
  use ExUnit.Case, async: true

  alias PipelinesAPI.SuperjerryClient.ResponseFormatter, as: RF

  alias InternalApi.Superjerry.{
    ListFlakyTestsResponse,
    Flaky,
    FlakyTestDetailsResponse,
    FlakyTestDetail,
    FlakyTestDisruptionsResponse,
    FlakyTestDisruption,
    ListFlakyHistoryResponse,
    DisruptionRecord
  }

  test "list response -> Scrivener page of flaky maps, project_id dropped" do
    resp =
      {:ok,
       %ListFlakyTestsResponse{
         flaky_tests: [
           %Flaky{
             project_id: "p",
             test_id: "t1",
             test_name: "spec",
             pass_rate: 80,
             labels: ["flaky"],
             disruptions_count: 3
           }
         ],
         total_rows: 1,
         total_pages: 1
       }}

    assert {:ok, %Scrivener.Page{entries: [row], total_entries: 1, total_pages: 1}} =
             RF.process_list_flaky_tests_response(resp, %{"page" => "1", "page_size" => "20"})

    assert row.test_id == "t1" and row.pass_rate == 80 and row.labels == ["flaky"]
    refute Map.has_key?(row, :project_id)
  end

  test "details response reshapes parallel arrays into per-context objects" do
    resp =
      {:ok,
       %FlakyTestDetailsResponse{
         detail: %FlakyTestDetail{
           id: "t1",
           name: "spec",
           contexts: ["ctx-a", "ctx-b"],
           pass_rates: [90.0, 80.0],
           p95_durations: [1.0, 2.0],
           impacts: [0.1, 0.2],
           total_counts: [10, 20],
           disruptions_count: [1, 2],
           hashes: ["h1", "h2"],
           available_contexts: ["ctx-a", "ctx-b"],
           selected_context: "ctx-a"
         }
       }}

    assert {:ok, detail} = RF.process_flaky_test_details_response(resp)
    assert detail.id == "t1"

    assert [
             %{context: "ctx-a", pass_rate: 90.0, p95_duration: 1.0, total_count: 10, hash: "h1"}
             | _
           ] = detail.contexts

    assert detail.selected_context == "ctx-a"
  end

  test "disruptions response rejects nil padding (latent superjerry bug guard)" do
    resp =
      {:ok,
       %FlakyTestDisruptionsResponse{
         disruptions: [nil, %FlakyTestDisruption{context: "c", hash: "h", run_id: "r"}],
         total_rows: 1,
         total_pages: 1
       }}

    assert {:ok, %Scrivener.Page{entries: entries}} =
             RF.process_flaky_test_disruptions_response(resp, %{
               "page" => "1",
               "page_size" => "10"
             })

    assert length(entries) == 1
    assert [%{context: "c", hash: "h", run_id: "r"}] = entries
  end

  test "disruptions page_size defaults to 10 when not specified" do
    resp =
      {:ok,
       %FlakyTestDisruptionsResponse{
         disruptions: [],
         total_rows: 0,
         total_pages: 1
       }}

    assert {:ok, %Scrivener.Page{page_size: page_size}} =
             RF.process_flaky_test_disruptions_response(resp, %{})

    assert page_size == 10
  end

  test "flaky list page_size defaults to 20 when not specified" do
    resp =
      {:ok,
       %ListFlakyTestsResponse{
         flaky_tests: [],
         total_rows: 0,
         total_pages: 1
       }}

    assert {:ok, %Scrivener.Page{page_size: page_size}} =
             RF.process_list_flaky_tests_response(resp, %{})

    assert page_size == 20
  end

  test "history response -> list of {day, count}" do
    resp =
      {:ok,
       %ListFlakyHistoryResponse{
         disruptions: [
           %DisruptionRecord{
             day: %Google.Protobuf.Timestamp{seconds: 1_700_000_000, nanos: 0},
             count: 5
           }
         ]
       }}

    assert {:ok, [%{day: day, count: 5}]} = RF.process_list_flaky_history_response(resp)
    assert is_binary(day)
  end

  test "errors pass through" do
    assert {:error, {:internal, "boom"}} =
             RF.process_list_flaky_tests_response({:error, {:internal, "boom"}}, %{})
  end
end
