defmodule PipelinesAPI.PipelinesClient.ResponseFormatter.Test do
  use ExUnit.Case

  alias PipelinesAPI.PipelinesClient.ResponseFormatter

  alias InternalApi.Plumber.{
    DescribeResponse,
    TerminateResponse,
    VersionResponse,
    ListResponse,
    GetProjectIdResponse,
    DescribeTopologyResponse,
    ValidateYamlResponse
  }

  alias InternalApi.Plumber.ResponseStatus
  alias InternalApi.Plumber.ResponseStatus.ResponseCode
  alias PipelinesAPI.Util.ToTuple
  alias InternalApi.Plumber.Pipeline.State

  # Describe

  test "process_describe_response() returns {:ok, description} when given valid params and state is done" do
    response = describe_response(:OK, "", false, State.value(:DONE)) |> ToTuple.ok()

    assert {:ok, description} = ResponseFormatter.process_describe_response(response)
    assert description == expected_description(false, "done")
  end

  test "process_describe_response() returns {:ok, description} when given valid params and state that is not done" do
    response = describe_response(:OK, "", false, State.value(:PENDING)) |> ToTuple.ok()

    assert {:ok, description} = ResponseFormatter.process_describe_response(response)
    assert description == expected_description(false, "pending")
  end

  test "process_describe_response() returns error and server message when server returns BAD_PARAM code" do
    response = describe_response(:BAD_PARAM, "Error message from server", false) |> ToTuple.ok()

    assert {:error, {:user, message}} = ResponseFormatter.process_describe_response(response)
    assert message == "Error message from server"
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

  defp describe_response(code, message, detailed, state \\ 3) do
    %{
      pipeline: %{
        ppl_id: "ppl_id1",
        branch_name: "master",
        commit_sha: "sha1",
        hook_id: "hook_id1",
        branch_id: "branch_id1",
        name: "Pipeline 1",
        project_id: "project_id1",
        terminate_request: "",
        created_at: %Google.Protobuf.Timestamp{nanos: 261_805_000, seconds: 1_525_877_331},
        pending_at: %Google.Protobuf.Timestamp{nanos: 261_805_000, seconds: 1_525_877_331},
        queuing_at: %Google.Protobuf.Timestamp{nanos: 261_805_000, seconds: 1_525_877_331},
        running_at: %Google.Protobuf.Timestamp{nanos: 261_805_000, seconds: 1_525_877_331},
        stopping_at: %Google.Protobuf.Timestamp{nanos: 261_805_000, seconds: 1_525_877_331},
        done_at: %Google.Protobuf.Timestamp{nanos: 261_805_000, seconds: 1_525_877_331},
        state: state,
        result: 1,
        result_reason: 2
      },
      blocks: blocks_desc(detailed),
      response_status: response_status(code, message)
    }
    |> DescribeResponse.new()
  end

  defp expected_description(detailed, state) do
    %{
      pipeline: expected_pipeline(state),
      blocks: expected_blocks_desc(detailed)
    }
  end

  defp expected_pipeline(state) do
    pipeline = %{
      ppl_id: "ppl_id1",
      branch_name: "master",
      commit_sha: "sha1",
      hook_id: "hook_id1",
      branch_id: "branch_id1",
      name: "Pipeline 1",
      project_id: "project_id1",
      terminate_request: "",
      created_at: "2018-05-09 14:48:51.261805Z",
      pending_at: "2018-05-09 14:48:51.261805Z",
      queuing_at: "2018-05-09 14:48:51.261805Z",
      running_at: "2018-05-09 14:48:51.261805Z",
      stopping_at: "2018-05-09 14:48:51.261805Z",
      done_at: "2018-05-09 14:48:51.261805Z",
      state: state,
      result: "stopped",
      result_reason: "stuck"
    }

    if state == "done" do
      pipeline
    else
      Map.drop(pipeline, [:result, :result_reason])
    end
  end

  defp blocks_desc(false), do: []

  defp expected_blocks_desc(false), do: []

  # Terminate

  test "process_terminate_response() returns {:ok, message} when given valid params" do
    response = terminate_response(:OK, "Message") |> ToTuple.ok()

    assert {:ok, message} = ResponseFormatter.process_terminate_response(response)
    assert message == "Message"
  end

  test "process_terminate_response() returns error and server message when server returns BAD_PARAM code" do
    response = terminate_response(:BAD_PARAM, "Error message from server") |> ToTuple.ok()

    assert {:error, {:user, message}} = ResponseFormatter.process_terminate_response(response)
    assert message == "Error message from server"
  end

  test "process_terminate_response() returns internal error when it receives {:ok, invalid_data}" do
    response = {:ok, "123"}

    assert {:error, {:internal, message}} = ResponseFormatter.process_terminate_response(response)
    assert message == "Internal error"
  end

  test "process_terminate_response() returns what it gets if it's not an :ok tuple" do
    response = {:error, {:user, "Error message"}}

    assert {:error, {:user, message}} = ResponseFormatter.process_terminate_response(response)
    assert message == "Error message"
  end

  defp terminate_response(code, message) do
    %{response_status: response_status(code, message)}
    |> TerminateResponse.new()
  end

  # List

  test "process_list_response() returns {:ok, Scriviner.Page} when given valid params" do
    response = list_response(:OK, "") |> ToTuple.ok()

    assert {:ok, page} = ResponseFormatter.process_list_response(response)
    assert %Scrivener.Page{entries: pipelines_list} = page
    assert is_list(pipelines_list)
    assert [%{ppl_id: "1"}, %{ppl_id: "2"}] == pipelines_list
  end

  test "process_list_response() returns error and server message when server returns BAD_PARAM code" do
    response = list_response(:BAD_PARAM, "Error message from server") |> ToTuple.ok()

    assert {:error, {:user, message}} = ResponseFormatter.process_list_response(response)
    assert message == "Error message from server"
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

  defp list_response(code, message) do
    %{
      pipelines: [
        %{ppl_id: "1"},
        %{ppl_id: "2"}
      ],
      response_status: response_status(code, message)
    }
    |> ListResponse.new()
  end

  # Get Project Id

  test "process_get_project_id_response returns project_id" do
    response = get_project_id_response(:OK, "") |> ToTuple.ok()

    assert {:ok, project_id} = ResponseFormatter.process_get_project_id_response(response)
    assert {:ok, _} = UUID.info(project_id)
  end

  test "process_get_project_id_response() returns internal error when it receives {:ok, invalid_data}" do
    response = {:ok, "123"}

    assert {:error, {:internal, message}} =
             ResponseFormatter.process_get_project_id_response(response)

    assert message == "Internal error"
  end

  test "process_get_project_id_response returns error" do
    response = {:error, {:user, "Error message"}}

    assert {:error, {:user, message}} =
             ResponseFormatter.process_get_project_id_response(response)

    assert message == "Error message"
  end

  defp get_project_id_response(code, message) do
    %{
      response_status: response_status(code, message),
      project_id: UUID.uuid4()
    }
    |> GetProjectIdResponse.new()
  end

  # Describe Topology

  test "process_describe_topology_response() returns blocks" do
    response = describe_topology_response(:OK, "") |> ToTuple.ok()

    assert {:ok, blocks} = ResponseFormatter.process_describe_topology_response(response)
    assert blocks == []
  end

  test "process_describe_topology_response() returns error" do
    response = {:error, {:user, "Error message"}}

    assert {:error, {:user, message}} =
             ResponseFormatter.process_describe_topology_response(response)

    assert message == "Error message"
  end

  test "process_describe_topology_response() returns internal error" do
    response = {:ok, "123"}

    assert {:error, {:internal, message}} =
             ResponseFormatter.process_describe_topology_response(response)

    assert message == "Internal error"
  end

  defp describe_topology_response(code, message) do
    %{
      status: response_status(code, message),
      blocks: []
    }
    |> DescribeTopologyResponse.new()
  end

  # Validate YAML

  test "process_validate_response() returns {:ok, %{message: msg, pipeline_id: ppl_id}} when given valid params" do
    response = validate_response(:OK, "Definition valid", "123") |> ToTuple.ok()

    assert {:ok, response} = ResponseFormatter.process_validate_response(response)
    assert is_map(response)
    assert Map.get(response, :message) == "Definition valid"
    assert Map.get(response, :pipeline_id) == "123"
  end

  test "process_validate_response() returns error and server message when server returns BAD_PARAM code" do
    response = validate_response(:BAD_PARAM, "Error message from server", "") |> ToTuple.ok()

    assert {:error, {:user, message}} = ResponseFormatter.process_validate_response(response)
    assert message == "Error message from server"
  end

  test "process_validate_response() returns internal error when it receives {:ok, invalid_data}" do
    response = {:ok, "123"}

    assert {:error, {:internal, message}} = ResponseFormatter.process_validate_response(response)
    assert message == "Internal error"
  end

  test "process_validate_response() returns what it gets if it's not an :ok tuple" do
    response = {:error, {:user, "Error message"}}

    assert {:error, {:user, message}} = ResponseFormatter.process_validate_response(response)
    assert message == "Error message"
  end

  defp validate_response(code, message, ppl_id) do
    %{
      ppl_id: ppl_id,
      response_status: response_status(code, message)
    }
    |> ValidateYamlResponse.new()
  end

  # Version

  test "process_version_response() returns {:ok, version} when given valid params" do
    response = version_response(:OK, "") |> ToTuple.ok()

    assert {:ok, version} = ResponseFormatter.process_version_response(response)
    assert version == "1.2.3"
  end

  test "process_version_response() returns internal error when it receives {:ok, invalid_data}" do
    response = {:ok, "123"}

    assert {:error, {:internal, message}} = ResponseFormatter.process_version_response(response)
    assert message == "Internal error"
  end

  test "process_version_response() returns what it gets if it's not an :ok tuple" do
    response = {:error, {:user, "Error message"}}

    assert {:error, {:user, message}} = ResponseFormatter.process_version_response(response)
    assert message == "Error message"
  end

  defp version_response(code, message) do
    %{version: "1.2.3", response_status: response_status(code, message)}
    |> VersionResponse.new()
  end

  defp response_status(code, message),
    do: ResponseStatus.new(code: ResponseCode.value(code), message: message)
end
