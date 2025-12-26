defmodule PipelinesAPI.PeriodicSchedulerClient.RequestFormatter.Test do
  use ExUnit.Case
  use Plug.Test

  alias PipelinesAPI.PeriodicSchedulerClient.RequestFormatter

  alias InternalApi.PeriodicScheduler.{
    ApplyRequest,
    GetProjectIdRequest,
    RunNowRequest,
    DescribeRequest,
    DeleteRequest,
    ListRequest
  }

  alias InternalApi.PeriodicScheduler.ParameterValue

  # Apply

  test "form_apply_request() returns internal error when it is not called with map as a param" do
    conn = create_conn(:apply)

    assert {:error, {:internal, "Internal error"}} ==
             RequestFormatter.form_apply_request(nil, conn)
  end

  test "form_apply_request() returns {:ok, request} when called with map with all params" do
    conn = create_conn(:apply)

    assert {:ok, request = %ApplyRequest{}} =
             RequestFormatter.form_apply_request(conn.params, conn)

    assert request.organization_id == "test_org"
    assert request.requester_id == "test_user"
    assert request.yml_definition == conn.params["yml_definition"]
  end

  # GetProjectId

  test "form_get_project_id_request() returns internal error when it is not called with map as a param" do
    conn = create_conn(:apply)

    assert {:error, {:internal, "Internal error"}} ==
             RequestFormatter.form_get_project_id_request(nil, conn)
  end

  test "form_get_project_id_request() returns {:ok, request} when called with map with all params" do
    conn = create_conn(:apply)
    params = %{"periodic_id" => UUID.uuid4(), "project_name" => "Project 1"}

    assert {:ok, request = %GetProjectIdRequest{}} =
             RequestFormatter.form_get_project_id_request(params, conn)

    assert request.organization_id == "test_org"
    assert request.periodic_id == params["periodic_id"]
    assert request.project_name == params["project_name"]
  end

  # Describe

  test "form_describe_request() returns internal error when it is not called with map as a param" do
    conn = create_conn(:describe)

    assert {:error, {:internal, "Internal error"}} ==
             RequestFormatter.form_describe_request(nil, conn)
  end

  test "form_describe_request() returns {:ok, request} when called with map with all params" do
    conn = create_conn(:describe)
    params = %{"periodic_id" => UUID.uuid4(), "periodic_name" => "First_schedule"}

    assert {:ok, request = %DescribeRequest{}} =
             RequestFormatter.form_describe_request(params, conn)

    assert request.id == params["periodic_id"]
  end

  # Delete

  test "form_delete_request() returns internal error when it is not called with map as a param" do
    conn = create_conn(:describe)

    assert {:error, {:internal, "Internal error"}} ==
             RequestFormatter.form_delete_request(nil, conn)
  end

  test "form_delete_request() returns {:ok, request} when called with map with all params" do
    conn = create_conn(:describe)
    params = %{"periodic_id" => UUID.uuid4()}
    assert {:ok, request = %DeleteRequest{}} = RequestFormatter.form_delete_request(params, conn)
    assert request.id == params["periodic_id"]
    assert request.requester == "test_user"
  end

  # List

  test "form_list_request() returns internal error when it is not called with map as a param" do
    conn = create_conn(:describe)

    assert {:error, {:internal, "Internal error"}} ==
             RequestFormatter.form_list_request(nil, conn)
  end

  test "form_list_request() returns user error when one of int params is not integer" do
    conn = create_conn(:describe)
    params = %{"project_id" => UUID.uuid4(), "page" => "asdf", "page_size" => 15}
    assert {:error, {:user, msg}} = RequestFormatter.form_list_request(params, conn)
    assert msg == "Invalid value of 'page' param: \"asdf\" - needs to be integer."
  end

  test "form_list_request() returns {:ok, request} when called with map with all params" do
    conn = create_conn(:describe)
    params = %{"project_id" => UUID.uuid4(), "page" => 4, "page_size" => 15}
    assert {:ok, request = %ListRequest{}} = RequestFormatter.form_list_request(params, conn)
    assert request.project_id == params["project_id"]
    assert request.page_size == params["page_size"]
    assert request.page == params["page"]
    assert request.organization_id == ""
    assert request.requester_id == ""
  end

  test "form_list_request() converts pagination params provided as strings" do
    conn = create_conn(:describe)

    params = %{
      "project_id" => UUID.uuid4(),
      "page" => "3",
      "page_size" => "25"
    }

    assert {:ok, %ListRequest{page: 3, page_size: 25}} =
             RequestFormatter.form_list_request(params, conn)
  end

  # Run Now

  test "form_run_now_request() returns internal error when it is not called with map as a param" do
    conn = create_conn(:run_now)

    assert {:error, {:internal, "Internal error"}} ==
             RequestFormatter.form_run_now_request(nil, conn)
  end

  test "form_run_now_request() returns {:ok, request} when called with legacy branch parameter" do
    conn = create_conn(:run_now)

    params = %{
      "branch" => "master",
      "pipeline_file" => ".semaphore/semaphore.yml",
      "periodic_id" => UUID.uuid4(),
      "parameters" => %{"param1" => "value1", "param2" => "value2"}
    }

    assert {:ok, request = %RunNowRequest{}} = RequestFormatter.form_run_now_request(params, conn)

    assert request.id == params["periodic_id"]
    assert request.requester == "test_user"
    assert request.reference == "refs/heads/master"
    assert request.pipeline_file == ".semaphore/semaphore.yml"

    assert request.parameter_values == [
             %ParameterValue{name: "param1", value: "value1"},
             %ParameterValue{name: "param2", value: "value2"}
           ]
  end

  test "form_run_now_request() returns {:ok, request} when called with new reference format - BRANCH" do
    conn = create_conn(:run_now)

    params = %{
      "reference" => %{
        "type" => "BRANCH",
        "name" => "feature/new-feature"
      },
      "pipeline_file" => ".semaphore/deploy.yml",
      "periodic_id" => UUID.uuid4(),
      "parameters" => %{"ENV" => "staging"}
    }

    assert {:ok, request = %RunNowRequest{}} = RequestFormatter.form_run_now_request(params, conn)

    assert request.id == params["periodic_id"]
    assert request.requester == "test_user"
    # BRANCH
    assert request.reference == "refs/heads/feature/new-feature"
    assert request.pipeline_file == ".semaphore/deploy.yml"

    assert request.parameter_values == [
             %ParameterValue{name: "ENV", value: "staging"}
           ]
  end

  test "form_run_now_request() returns {:ok, request} when called with new reference format - TAG" do
    conn = create_conn(:run_now)

    params = %{
      "reference" => %{
        "type" => "TAG",
        "name" => "v1.2.0"
      },
      "pipeline_file" => ".semaphore/release.yml",
      "periodic_id" => UUID.uuid4()
    }

    assert {:ok, request = %RunNowRequest{}} = RequestFormatter.form_run_now_request(params, conn)

    assert request.id == params["periodic_id"]
    assert request.requester == "test_user"
    # TAG
    assert request.reference == "refs/tags/v1.2.0"
    assert request.pipeline_file == ".semaphore/release.yml"
    assert request.parameter_values == []
  end

  test "form_run_now_request() returns {:ok, request} when called with map with missing params" do
    conn = create_conn(:run_now)
    params = %{"periodic_id" => UUID.uuid4()}
    assert {:ok, request = %RunNowRequest{}} = RequestFormatter.form_run_now_request(params, conn)

    assert request.id == params["periodic_id"]
    assert request.requester == "test_user"
    assert request.reference == ""
    assert request.pipeline_file == ""
    assert request.parameter_values == []
  end

  # Utility

  defp create_conn(action) do
    action
    |> init_conn()
    |> put_req_header("x-semaphore-user-id", "test_user")
    |> put_req_header("x-semaphore-org-id", "test_org")
  end

  defp init_conn(:describe) do
    conn(:get, "/schedules/First_schedule")
  end

  defp init_conn(:apply) do
    def =
      "apiVersion: v1.0\nkind: Periodic\nmetadata:\n  name: First periodic\n" <>
        "spec:\n  project: pipelines-test-repo-auto-call_II\n  branch: master\n" <>
        "  at: \"*/5 * * * *\"\n  pipeline_file: .semaphore/semaphore.yml\n"

    json_payload = %{yml_definition: def}

    conn(:post, "/schedules", Poison.encode!(json_payload))
    |> put_req_header("content-type", "application/json")
    |> parse()
  end

  defp init_conn(:run_now) do
    json_payload = %{
      branch: "master",
      pipeline_file: ".semaphore/semaphore.yml",
      parameters: %{"param1" => "value1", "param2" => "value2"}
    }

    conn(:post, "/schedules/#{UUID.uuid4()}/run_now", Poison.encode!(json_payload))
    |> put_req_header("content-type", "application/json")
    |> parse()
  end

  defp parse(conn) do
    opts = [
      pass: ["application/json"],
      json_decoder: Poison,
      parsers: [Plug.Parsers.JSON]
    ]

    Plug.Parsers.call(conn, Plug.Parsers.init(opts))
  end
end
