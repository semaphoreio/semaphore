defmodule Front.ActivityMonitor.Actions.Test do
  use Front.TestCase

  alias Front.ActivityMonitor.Actions
  alias Support.Factories

  setup do
    user_id = UUID.uuid4()
    org_id = UUID.uuid4()

    Support.Stubs.Feature.enable_feature(org_id, :permission_patrol)
    Support.Stubs.PermissionPatrol.allow_everything(org_id, user_id)

    [
      ppl_id: UUID.uuid4(),
      user_id: user_id,
      org_id: org_id,
      project_id: UUID.uuid4(),
      job_id: UUID.uuid4()
    ]
  end

  test "stop() calls all required APIs and returns :ok when given valid pipeline data", %{
    user_id: user_id,
    org_id: org_id,
    ppl_id: ppl_id,
    project_id: project_id
  } do
    Support.Stubs.PermissionPatrol.allow_everything(org_id, user_id)

    response = Factories.Pipeline.terminate_response()
    GrpcMock.stub(PipelineMock, :terminate, response)

    response =
      InternalApi.Plumber.DescribeResponse.new(
        pipeline: Support.Factories.pipeline(ppl_id: ppl_id, project_id: project_id),
        response_status:
          InternalApi.Plumber.ResponseStatus.new(
            code: InternalApi.Plumber.ResponseStatus.ResponseCode.value(:OK)
          ),
        blocks: []
      )

    GrpcMock.stub(PipelineMock, :describe, response)

    assert :ok == Actions.stop(org_id, user_id, "Pipeline", ppl_id)
  end

  test "stop() calls all required APIs and returns :ok when given valid job data", %{
    user_id: user_id,
    org_id: org_id,
    job_id: job_id,
    project_id: project_id
  } do
    Support.Stubs.PermissionPatrol.allow_everything(org_id, user_id)

    job_stop_resp =
      InternalApi.ServerFarm.Job.StopResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))
      )

    GrpcMock.stub(InternalJobMock, :stop, job_stop_resp)

    job_desc_resp =
      InternalApi.ServerFarm.Job.DescribeResponse.new(
        job: Support.Factories.job(job_id, project_id),
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))
      )

    GrpcMock.stub(InternalJobMock, :describe, job_desc_resp)

    assert :ok == Actions.stop(org_id, user_id, "Debug Session", job_id)
  end
end
