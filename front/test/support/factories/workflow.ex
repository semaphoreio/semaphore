defmodule Support.Factories.Workflow do
  alias InternalApi.PlumberWF.DescribeResponse
  alias InternalApi.PlumberWF.GetPathResponse
  alias InternalApi.PlumberWF.GetPathResponse.PathElement
  alias InternalApi.PlumberWF.WorkflowDetails
  alias InternalApi.Status

  def describe_response do
    %DescribeResponse{
      status: %Status{code: Google.Rpc.Code.value(:OK), message: ""},
      workflow:
        WorkflowDetails.new(
          wf_id: "62f8cf42-2ef7-4fe7-9b28-396b324bedf5",
          initial_ppl_id: "running",
          project_id: "62f8cf42-2ef7-4fe7-9b28-396b324bedf5",
          hook_id: "62f8cf42-2ef7-4fe7-9b28-396b324bedf5",
          requester_id: "9865c64d-783a-46e1-b659-2194b1d69494",
          branch_id: "62f8cf42-2ef7-4fe7-9b28-396b324bedf5",
          branch_name: "master",
          commit_sha: "03vaw34",
          created_at: %Google.Protobuf.Timestamp{seconds: 12_345, nanos: 54_321},
          triggered_by: 0,
          rerun_of: ""
        )
    }
  end

  def reschedule_response do
    %InternalApi.PlumberWF.ScheduleResponse{
      wf_id: "8d76e1a5-b1db-45db-818e-ecab3c9a9904",
      ppl_id: "8d76e1a5-b1db-45db-818e-ecab3c9a9904",
      status: %Status{code: Google.Rpc.Code.value(:OK), message: ""}
    }
  end

  def bad_describe_response do
    %DescribeResponse{
      status: %Status{code: Google.Rpc.Code.value(:NOT_FOUND), message: ""}
    }
  end

  def get_path_response do
    GetPathResponse.new(
      path: [
        PathElement.new(ppl_id: "3fd07895-e15b-43c4-8ee2-0ad18ce75507", switch_id: "1")
      ]
    )
  end

  def get_path_long_response do
    GetPathResponse.new(
      path: [
        PathElement.new(ppl_id: "1", switch_id: "1"),
        PathElement.new(ppl_id: "1", switch_id: "1"),
        PathElement.new(ppl_id: "1", switch_id: "1")
      ]
    )
  end
end
