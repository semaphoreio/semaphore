defmodule PipelinesAPI.SuperjerryClientTest do
  use ExUnit.Case

  alias PipelinesAPI.SuperjerryClient
  alias InternalApi.Superjerry.{ListFlakyTestsResponse, Flaky}

  setup do
    Support.Stubs.reset()
    System.put_env("INTERNAL_API_URL_SUPERJERRY", "127.0.0.1:50052")
    :ok
  end

  test "list_flaky_tests calls the stub and returns the paginated page" do
    GrpcMock.stub(SuperjerryMock, :list_flaky_tests, fn _req, _stream ->
      %ListFlakyTestsResponse{
        flaky_tests: [
          %Flaky{
            project_id: "",
            test_id: "t1",
            test_name: "spec",
            test_group: "",
            test_runner: "",
            test_file: "",
            test_suite: "",
            pass_rate: 80,
            labels: [],
            disruptions_count: 3,
            latest_disruption_hash: "",
            latest_disruption_run_id: "",
            resolved: false,
            scheduled: false,
            ticket_url: "",
            age: 0,
            total_count: 0
          }
        ],
        total_rows: 1,
        total_pages: 1
      }
    end)

    assert {:ok, page} =
             SuperjerryClient.list_flaky_tests(%{
               "org_id" => "org-1",
               "project_id" => "proj-1",
               "page" => "1",
               "page_size" => "20"
             })

    assert %Scrivener.Page{} = page
    assert [%{test_id: "t1", test_name: "spec"}] = page.entries
  end

  test "flaky_test_details returns a reshaped detail" do
    alias InternalApi.Superjerry.{FlakyTestDetailsResponse, FlakyTestDetail}

    GrpcMock.stub(SuperjerryMock, :flaky_test_details, fn _req, _s ->
      %FlakyTestDetailsResponse{
        detail: %FlakyTestDetail{
          project_id: "",
          id: "t1",
          name: "spec",
          group: "",
          runner: "",
          file: "",
          labels: [],
          selected_context: "c",
          contexts: ["c"],
          pass_rates: [90.0],
          p95_durations: [1.0],
          impacts: [0.0],
          total_counts: [1],
          disruptions_count: [1],
          hashes: ["h"],
          available_contexts: ["c"]
        }
      }
    end)

    assert {:ok, %{id: "t1", contexts: [%{context: "c"}]}} =
             SuperjerryClient.flaky_test_details(%{
               "org_id" => "o",
               "project_id" => "p",
               "test_id" => "t1"
             })
  end

  test "list_flaky_history returns a {day,count} list" do
    alias InternalApi.Superjerry.{ListFlakyHistoryResponse, DisruptionRecord}

    GrpcMock.stub(SuperjerryMock, :list_flaky_history, fn _req, _s ->
      %ListFlakyHistoryResponse{
        disruptions: [%DisruptionRecord{count: 2}]
      }
    end)

    assert {:ok, [%{count: 2, day: nil}]} =
             SuperjerryClient.list_flaky_history(%{"org_id" => "o", "project_id" => "p"})
  end
end
