defmodule JobPage.Models.JobTest do
  use FrontWeb.ConnCase

  describe "construct" do
    @tag :skip
    test "when job has no starting time but it is mark as passed => returns 0 for timer" do
      job_desc_resp =
        InternalApi.ServerFarm.Job.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          job:
            InternalApi.ServerFarm.Job.Job.new(
              id: "21212121-be8a-465a-b9cd-81970fb802c6",
              name: "RSpec 342/706",
              project_id: "78114608-be8a-465a-b9cd-81970fb802c6",
              branch_id: "78114608-be8a-465a-b9cd-81970fb802c6",
              hook_id: "78114608-be8a-465a-b9cd-81970fb802c6",
              ppl_id: "78114608-be8a-465a-b9cd-81970fb802c6",
              timeline:
                InternalApi.ServerFarm.Job.Job.Timeline.new(
                  created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_259),
                  enqueued_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_260),
                  started_at: nil,
                  finished_at: nil
                ),
              state: InternalApi.ServerFarm.Job.Job.State.value(:FINISHED),
              result: InternalApi.ServerFarm.Job.Job.Result.value(:PASSED),
              build_server: "127.0.0.1",
              self_hosted: false,
              stopped_by: ""
            )
        )

      GrpcMock.stub(InternalJobMock, :describe, job_desc_resp)

      job = JobPage.Models.Job.find("foo", nil)

      assert job.timer == 0
    end
  end
end
