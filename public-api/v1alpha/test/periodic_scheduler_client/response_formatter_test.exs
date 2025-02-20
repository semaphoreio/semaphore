defmodule PipelinesAPI.PeriodicSchedulerClient.ResponseFormatter.Test do
  use ExUnit.Case

  alias PipelinesAPI.PeriodicSchedulerClient.ResponseFormatter

  alias InternalApi.PeriodicScheduler.{
    ApplyResponse,
    GetProjectIdResponse,
    RunNowResponse,
    DescribeResponse,
    DeleteResponse,
    ListResponse
  }

  alias Util.Proto

  # Apply

  test "process_apply_response() returns {:ok, msg} when given valid params" do
    id = UUID.uuid4()
    response = apply_response(:OK, "Everything OK", id)

    assert {:ok, resp_id} = ResponseFormatter.process_apply_response(response)
    assert id == resp_id
  end

  test "process_apply_response() returns error and server message when server
        returns INVALID_ARGUMENT or FAILED_PRECONDITION" do
    response = apply_response(:INVALID_ARGUMENT, "INVALID_ARGUMENT message from server")

    assert {:error, {:user, message}} = ResponseFormatter.process_apply_response(response)
    assert message == "INVALID_ARGUMENT message from server"

    response = apply_response(:FAILED_PRECONDITION, "FAILED_PRECONDITION message from server")

    assert {:error, {:user, message}} = ResponseFormatter.process_apply_response(response)
    assert message == "FAILED_PRECONDITION message from server"
  end

  test "process_apply_response() returns internal error when it receives {:ok, invalid_data}" do
    response = {:ok, "123"}

    assert {:error, {:internal, message}} = ResponseFormatter.process_apply_response(response)
    assert message == "Internal error"
  end

  test "process_apply_response() returns what it gets if it's not an :ok tuple" do
    response = {:error, {:user, "Error message"}}

    assert {:error, {:user, message}} = ResponseFormatter.process_apply_response(response)
    assert message == "Error message"
  end

  defp apply_response(code, message, id \\ "") do
    params = %{id: id, status: %{code: code, message: message}}
    Proto.deep_new(ApplyResponse, params)
  end

  # GetProjectId

  test "process_get_project_id_response() returns {:ok, msg} when given valid params" do
    id = UUID.uuid4()
    response = get_project_id_response(:OK, "Everything OK", id)

    assert {:ok, resp_id} = ResponseFormatter.process_get_project_id_response(response)
    assert id == resp_id
  end

  test "process_get_project_id_response() returns error and server message when server
        returns INVALID_ARGUMENT or NOT_FOUND" do
    response = get_project_id_response(:INVALID_ARGUMENT, "INVALID_ARGUMENT message from server")

    assert {:error, {:user, message}} =
             ResponseFormatter.process_get_project_id_response(response)

    assert message == "INVALID_ARGUMENT message from server"

    response = get_project_id_response(:NOT_FOUND, "NOT_FOUND message from server")

    assert {:error, {:user, message}} =
             ResponseFormatter.process_get_project_id_response(response)

    assert message == "NOT_FOUND message from server"
  end

  test "process_get_project_id_response() returns internal error when it receives {:ok, invalid_data}" do
    response = {:ok, "123"}

    assert {:error, {:internal, message}} =
             ResponseFormatter.process_get_project_id_response(response)

    assert message == "Internal error"
  end

  test "process_get_project_id_response() returns what it gets if it's not an :ok tuple" do
    response = {:error, {:user, "Error message"}}

    assert {:error, {:user, message}} =
             ResponseFormatter.process_get_project_id_response(response)

    assert message == "Error message"
  end

  defp get_project_id_response(code, message, id \\ "") do
    params = %{project_id: id, status: %{code: code, message: message}}
    Proto.deep_new(GetProjectIdResponse, params)
  end

  # Describe

  test "process_describe_response() returns {:ok, description} when given valid params" do
    assert {:ok, proto} = describe_response(:OK)

    assert {:ok, resp} = ResponseFormatter.process_describe_response({:ok, proto})

    assert proto.periodic |> Map.from_struct() |> Map.delete(:updated_at) ==
             resp.schedule |> Map.delete(:updated_at)

    assert resp.schedule.updated_at == "2018-12-12 09:26:53.765473Z"

    assert proto.triggers
           |> Enum.at(0)
           |> Map.from_struct()
           |> Map.drop([:triggered_at, :scheduled_at]) ==
             resp.triggers |> Enum.at(0) |> Map.drop([:triggered_at, :scheduled_at])

    assert resp.triggers |> Enum.at(0) |> Map.get(:triggered_at) == "2018-12-12 09:26:53.765473Z"
    assert resp.triggers |> Enum.at(0) |> Map.get(:scheduled_at) == "2018-12-12 09:26:53.765473Z"

    assert proto.triggers
           |> Enum.at(1)
           |> Map.from_struct()
           |> Map.drop([:triggered_at, :scheduled_at]) ==
             resp.triggers |> Enum.at(1) |> Map.drop([:triggered_at, :scheduled_at])

    assert resp.triggers |> Enum.at(1) |> Map.get(:triggered_at) == "2018-12-12 09:26:53.765473Z"
    assert resp.triggers |> Enum.at(1) |> Map.get(:scheduled_at) == "2018-12-12 09:26:53.765473Z"
  end

  test "process_describe_response() returns error and server message when server returns
        INVALID_ARGUMENT or NOT_FOUND" do
    response = describe_response(:INVALID_ARGUMENT, "INVALID_ARGUMENT message from server")

    assert {:error, {:user, message}} = ResponseFormatter.process_describe_response(response)
    assert message == "INVALID_ARGUMENT message from server"

    response = describe_response(:NOT_FOUND, "NOT_FOUND message from server")

    assert {:error, {:user, message}} = ResponseFormatter.process_describe_response(response)
    assert message == "NOT_FOUND message from server"
  end

  test "process_describe_response() returns internal error when it receives {:ok, invalid_data}" do
    response = {:ok, "123"}

    assert {:error, {:internal, message}} = ResponseFormatter.process_describe_response(response)
    assert message == "Internal error"
  end

  test "process_describe_response() returns what it gets if it's not an :ok tuple" do
    response = {:error, {:user, "Error message"}}

    assert {:error, {:user, message}} = ResponseFormatter.process_describe_response(response)
    assert message == "Error message"
  end

  defp describe_response(:OK) do
    periodic = %{
      id: UUID.uuid4(),
      name: "First periodic",
      project_id: UUID.uuid4(),
      branch: "master",
      at: "* * * * *",
      pipeline_file: ".semaphore/semaphore.yml",
      requester_id: UUID.uuid4(),
      updated_at: %{nanos: 765_473_000, seconds: 1_544_606_813}
    }

    tr = %{
      triggered_at: %{nanos: 765_473_000, seconds: 1_544_606_813},
      project_id: UUID.uuid4(),
      branch: "master",
      pipeline_file: ".semaphore/semaphore.yml",
      scheduling_status: "passed",
      scheduled_workflow_id: UUID.uuid4(),
      scheduled_at: %{nanos: 765_473_000, seconds: 1_544_606_813},
      error_description: ""
    }

    params = %{periodic: periodic, triggers: [tr, tr], status: %{code: :OK}}
    Proto.deep_new(DescribeResponse, params)
  end

  defp describe_response(code, message) do
    params = %{status: %{code: code, message: message}}
    Proto.deep_new(DescribeResponse, params)
  end

  # Delete

  test "process_delete_response() returns {:ok, msg} when given valid params" do
    response = delete_response(:OK, "Everything OK")

    assert {:ok, message} = ResponseFormatter.process_delete_response(response)
    assert message == "Schedule successfully deleted."
  end

  test "process_delete_response() returns error and server message when server
        returns INVALID_ARGUMENT or NOT_FOUND" do
    response = delete_response(:INVALID_ARGUMENT, "INVALID_ARGUMENT message from server")

    assert {:error, {:user, message}} = ResponseFormatter.process_delete_response(response)
    assert message == "INVALID_ARGUMENT message from server"

    response = delete_response(:NOT_FOUND, "NOT_FOUND message from server")

    assert {:error, {:user, message}} = ResponseFormatter.process_delete_response(response)
    assert message == "NOT_FOUND message from server"
  end

  test "process_delete_response() returns internal error when it receives {:ok, invalid_data}" do
    response = {:ok, "123"}

    assert {:error, {:internal, message}} = ResponseFormatter.process_delete_response(response)
    assert message == "Internal error"
  end

  test "process_delete_response() returns what it gets if it's not an :ok tuple" do
    response = {:error, {:user, "Error message"}}

    assert {:error, {:user, message}} = ResponseFormatter.process_delete_response(response)
    assert message == "Error message"
  end

  defp delete_response(code, message) do
    params = %{status: %{code: code, message: message}}
    Proto.deep_new(DeleteResponse, params)
  end

  # List

  test "process_list_response() returns {:ok, description} when given valid params" do
    assert {:ok, proto} = list_response(:OK)

    assert {:ok, resp = %Scrivener.Page{}} = ResponseFormatter.process_list_response({:ok, proto})
    assert resp.page_number == 1
    assert resp.page_size == 30
    assert resp.total_entries == 3
    assert resp.total_pages == 1

    resp.entries
    |> Enum.with_index()
    |> Enum.map(fn {periodic, ind} ->
      assert proto.periodics |> Enum.at(ind) |> Map.from_struct() |> Map.delete(:updated_at) ==
               periodic |> Map.delete(:updated_at)

      assert periodic.updated_at == "2018-12-12 09:26:53.765473Z"
    end)
  end

  test "process_list_response() returns error and server message when server returns INVALID_ARGUMENT" do
    response = list_response(:INVALID_ARGUMENT, "INVALID_ARGUMENT message from server")

    assert {:error, {:user, message}} = ResponseFormatter.process_list_response(response)
    assert message == "INVALID_ARGUMENT message from server"
  end

  test "process_list_response() returns internal error when it receives {:ok, invalid_data}" do
    response = {:ok, "123"}

    assert {:error, {:internal, message}} = ResponseFormatter.process_list_response(response)
    assert message == "Internal error"
  end

  test "process_list_response() returns what it gets if it's not an :ok tuple" do
    response = {:error, {:user, "Error message"}}

    assert {:error, {:user, message}} = ResponseFormatter.process_list_response(response)
    assert message == "Error message"
  end

  defp list_response(:OK) do
    pr = %{
      id: UUID.uuid4(),
      name: "First periodic",
      project_id: UUID.uuid4(),
      branch: "master",
      at: "* * * * *",
      pipeline_file: ".semaphore/semaphore.yml",
      requester_id: UUID.uuid4(),
      updated_at: %{nanos: 765_473_000, seconds: 1_544_606_813}
    }

    params = %{
      periodics: [pr, pr, pr],
      status: %{code: :OK},
      page_number: 1,
      page_size: 30,
      total_entries: 3,
      total_pages: 1
    }

    Proto.deep_new(ListResponse, params)
  end

  defp list_response(code, message) do
    params = %{status: %{code: code, message: message}}
    Proto.deep_new(ListResponse, params)
  end

  # Run Now

  test "process_run_now_response() returns {:ok, description} when given valid params" do
    assert {:ok, proto} = run_now_response(:OK)

    assert {:ok, %{workflow_id: workflow_id}} =
             ResponseFormatter.process_run_now_response({:ok, proto})

    assert workflow_id == proto.triggers |> Enum.at(0) |> Map.get(:scheduled_workflow_id)
  end

  test "process_run_now_response() returns error and server message when server returns INVALID_ARGUMENT" do
    response = run_now_response(:INVALID_ARGUMENT, "INVALID_ARGUMENT message from server")

    assert {:error, {:user, message}} = ResponseFormatter.process_run_now_response(response)
    assert message == "INVALID_ARGUMENT message from server"
  end

  test "process_run_now_response() returns error and server message when server returns RESOURCE_EXHAUSTED" do
    response = run_now_response(:RESOURCE_EXHAUSTED, "RESOURCE_EXHAUSTED message from server")

    assert {:error, {:user, message}} = ResponseFormatter.process_run_now_response(response)
    assert message == "RESOURCE_EXHAUSTED message from server"
  end

  test "process_run_now_response() returns internal error when it receives {:ok, invalid_data}" do
    assert {:error, {:internal, "Internal error"}} =
             ResponseFormatter.process_run_now_response({:ok, "123"})
  end

  test "process_run_now_response() returns what it gets if it's not an :ok tuple" do
    assert {:error, {:user, "Error message"}} =
             ResponseFormatter.process_run_now_response({:error, {:user, "Error message"}})
  end

  defp run_now_response(:OK) do
    periodic = %{
      id: UUID.uuid4(),
      name: "First periodic",
      project_id: UUID.uuid4(),
      branch: "master",
      at: "* * * * *",
      pipeline_file: ".semaphore/semaphore.yml",
      requester_id: UUID.uuid4(),
      updated_at: %{nanos: 765_473_000, seconds: 1_544_606_813}
    }

    tr = %{
      triggered_at: %{nanos: 765_473_000, seconds: 1_544_606_813},
      project_id: UUID.uuid4(),
      branch: "master",
      pipeline_file: ".semaphore/semaphore.yml",
      scheduling_status: "passed",
      scheduled_workflow_id: UUID.uuid4(),
      scheduled_at: %{nanos: 765_473_000, seconds: 1_544_606_813},
      error_description: ""
    }

    params = %{periodic: periodic, triggers: [tr, tr], trigger: tr, status: %{code: :OK}}
    Proto.deep_new(RunNowResponse, params)
  end

  defp run_now_response(code, message) do
    params = %{status: %{code: code, message: message}}
    Proto.deep_new(DescribeResponse, params)
  end
end
