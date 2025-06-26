defmodule Support.Factories.Pipeline do
  alias InternalApi.Plumber

  alias InternalApi.Plumber.{
    Block,
    DescribeResponse,
    DescribeTopologyResponse,
    PartialRebuildResponse,
    Pipeline,
    ResponseStatus,
    TerminateResponse
  }

  alias Google.Protobuf.Timestamp
  alias InternalApi.Plumber.Block
  alias InternalApi.Plumber.Pipeline.Result, as: PipelineResult
  alias InternalApi.Plumber.Pipeline.ResultReason, as: PipelineResultReason
  alias InternalApi.Plumber.Pipeline.State, as: PipelineState
  alias InternalApi.Plumber.ResponseStatus.ResponseCode

  def terminate_response do
    %TerminateResponse{
      response_status: ResponseStatus.new()
    }
  end

  def partial_rebuild_response do
    %PartialRebuildResponse{
      response_status: ResponseStatus.new(code: ResponseCode.value(:OK)),
      ppl_id: "new-pipeline-id-#{:rand.uniform(10000)}"
    }
  end

  def list_response do
    InternalApi.Plumber.ListResponse.new(
      response_status: InternalApi.Plumber.ResponseStatus.new(),
      pipelines: [
        InternalApi.Plumber.Pipeline.new(
          ppl_id: "554b24bd-9b74-47a0-94c4-5d1063259cf4",
          name: "Build & Test",
          project_id: "2ad5b94e-fdcc-4950-bccb-f4f4880b53fc",
          branch_name: "master",
          commit_sha: "9298cf2c57d18abfeb6868853a7bcc032c936e0d",
          created_at:
            Google.Protobuf.Timestamp.new(
              seconds: 1_542_198_130,
              nanos: 846_654_000
            ),
          pending_at:
            Google.Protobuf.Timestamp.new(
              seconds: 1_542_198_133,
              nanos: 807_023_000
            ),
          queuing_at:
            Google.Protobuf.Timestamp.new(
              seconds: 1_542_198_133,
              nanos: 905_261_000
            ),
          running_at:
            Google.Protobuf.Timestamp.new(
              seconds: 1_542_198_133,
              nanos: 984_316_000
            ),
          stopping_at:
            Google.Protobuf.Timestamp.new(
              seconds: 0,
              nanos: 0
            ),
          done_at:
            Google.Protobuf.Timestamp.new(
              seconds: 1_542_198_145,
              nanos: 104_241_000
            ),
          state: PipelineState.value(:DONE),
          result: PipelineResult.value(:PASSED),
          result_reason: PipelineResultReason.value(:TEST),
          hook_id: "5301c914-2a2c-4928-8dcf-828cd7579df9",
          branch_id: "c082f06d-4913-41ff-b754-dbd7ad50dfe4",
          switch_id: "ad1a747a-aaa8-41e5-b99c-5e35cc77397d",
          working_directory: ".semaphore",
          yaml_file_name: "semaphore.yml",
          wf_id: "5301c914-2a2c-4928-8dcf-828cd7579df9",
          error_description: "",
          terminated_by: "",
          snapshot_id: "",
          terminate_request: ""
        ),
        InternalApi.Plumber.Pipeline.new(
          ppl_id: "bf2a81cf-5c93-43bf-8304-a9e35ebd7714",
          name: "Build & Test",
          project_id: "2ad5b94e-fdcc-4950-bccb-f4f4880b53fc",
          branch_name: "master",
          commit_sha: "51de1acc9a50991354e889330b9206b2b9e5a6f7",
          created_at:
            Google.Protobuf.Timestamp.new(
              seconds: 1_542_198_036,
              nanos: 206_153_000
            ),
          pending_at:
            Google.Protobuf.Timestamp.new(
              seconds: 1_542_198_038,
              nanos: 929_046_000
            ),
          queuing_at:
            Google.Protobuf.Timestamp.new(
              seconds: 1_542_198_038,
              nanos: 974_680_000
            ),
          running_at:
            Google.Protobuf.Timestamp.new(
              seconds: 1_542_198_039,
              nanos: 70_236_000
            ),
          stopping_at:
            Google.Protobuf.Timestamp.new(
              seconds: 0,
              nanos: 0
            ),
          done_at:
            Google.Protobuf.Timestamp.new(
              seconds: 1_542_198_049,
              nanos: 4_705_000
            ),
          state: PipelineState.value(:DONE),
          result: PipelineResult.value(:PASSED),
          result_reason: PipelineResultReason.value(:TEST),
          hook_id: "6ff0ee4d-febe-478d-b414-6b520368df96",
          branch_id: "c082f06d-4913-41ff-b754-dbd7ad50dfe4",
          switch_id: "6991d7f4-66b8-4227-9284-e51f00932250",
          working_directory: ".semaphore",
          yaml_file_name: "semaphore.yml",
          wf_id: "6ff0ee4d-febe-478d-b414-6b520368df96",
          error_description: "",
          terminated_by: "",
          snapshot_id: "",
          terminate_request: ""
        ),
        InternalApi.Plumber.Pipeline.new(
          ppl_id: "4811b969-ca40-4d50-b0b4-ff484a4a71da",
          name: "Build & Test",
          project_id: "2ad5b94e-fdcc-4950-bccb-f4f4880b53fc",
          branch_name: "master",
          commit_sha: "0a04a1d88a34c620b8de5ec53507de3339f5be89",
          created_at:
            Google.Protobuf.Timestamp.new(
              seconds: 1_542_038_114,
              nanos: 956_036_000
            ),
          pending_at:
            Google.Protobuf.Timestamp.new(
              seconds: 1_542_038_119,
              nanos: 876_956_000
            ),
          queuing_at:
            Google.Protobuf.Timestamp.new(
              seconds: 1_542_038_119,
              nanos: 975_578_000
            ),
          running_at:
            Google.Protobuf.Timestamp.new(
              seconds: 1_542_038_120,
              nanos: 511_647_000
            ),
          stopping_at:
            Google.Protobuf.Timestamp.new(
              seconds: 0,
              nanos: 0
            ),
          done_at:
            Google.Protobuf.Timestamp.new(
              seconds: 1_542_038_133,
              nanos: 672_039_000
            ),
          state: PipelineState.value(:DONE),
          result: PipelineResult.value(:PASSED),
          result_reason: PipelineResultReason.value(:TEST),
          hook_id: "0c9e25a6-ccd7-4628-9640-64b306a91b00",
          branch_id: "c082f06d-4913-41ff-b754-dbd7ad50dfe4",
          switch_id: "3bcb5d81-aa2a-4b7d-8582-073b4b4604fa",
          working_directory: ".semaphore",
          yaml_file_name: "semaphore.yml",
          wf_id: "0c9e25a6-ccd7-4628-9640-64b306a91b00",
          terminated_by: "",
          error_description: "",
          snapshot_id: "",
          terminate_request: ""
        )
      ],
      page_number: 1,
      page_size: 3,
      total_entries: 18,
      total_pages: 6
    )
  end

  def describe_topology_response do
    %DescribeTopologyResponse{
      blocks: [
        %DescribeTopologyResponse.Block{
          name: "block 1",
          jobs: ["job 1", "job 2", "job 3"],
          dependencies: []
        }
      ],
      after_pipeline: %DescribeTopologyResponse.AfterPipeline{
        jobs: []
      },
      status: %ResponseStatus{code: 0, message: ""}
    }
  end

  def describe_response do
    DescribeResponse.new(
      response_status: ResponseStatus.new(code: ResponseCode.value(:OK)),
      pipeline: pipeline(),
      blocks: [
        Block.new(
          block_id: "1",
          name: "Block 1",
          build_req_id: "1",
          state: Block.State.value(:RUNNING)
        ),
        Block.new(
          block_id: "2",
          name: "Block 2",
          build_req_id: "1",
          state: Block.State.value(:RUNNING)
        ),
        Block.new(
          block_id: "3",
          name: "Block 3",
          build_req_id: "1",
          state: Block.State.value(:RUNNING)
        )
      ]
    )
  end

  def describe_response(ppl) do
    DescribeResponse.new(
      response_status: ResponseStatus.new(code: ResponseCode.value(:OK)),
      pipeline:
        Pipeline.new(
          name: ppl |> Map.get(:name, "My First Pipeline"),
          ppl_id: ppl.id,
          project_id: "7e5ea0ae-3477-4d15-b3e9-768db905b9a2",
          branch_id: "7e5ea0ae-3477-4d15-b3e9-768db905b9a2",
          hook_id: "7e5ea0ae-3477-4d15-b3e9-768db905b9a2",
          branch_name: "master",
          commit_sha: "1234567",
          state: Pipeline.State.value(ppl.state),
          result: Pipeline.Result.value(ppl.result),
          created_at: Timestamp.new(seconds: ppl |> Map.get(:created_at, 0)),
          pending_at: Timestamp.new(seconds: ppl |> Map.get(:pending_at, 0)),
          queuing_at: Timestamp.new(seconds: ppl |> Map.get(:queuing_at, 0)),
          running_at: Timestamp.new(seconds: ppl |> Map.get(:running_at, 0)),
          stopping_at: Timestamp.new(seconds: ppl |> Map.get(:stopping_at, 0)),
          done_at: Timestamp.new(seconds: ppl |> Map.get(:done_at, 0)),
          switch_id: ppl.switch_id,
          error_description: ppl |> Map.get(:error_description, ""),
          terminated_by: ppl |> Map.get(:terminated_by, "")
        ),
      blocks: [
        Block.new(
          block_id: "1",
          name: "Block 1",
          build_req_id: "1",
          state: Block.State.value(:RUNNING)
        ),
        Block.new(
          block_id: "2",
          name: "Block 2",
          build_req_id: "1",
          state: Block.State.value(:RUNNING)
        ),
        Block.new(
          block_id: "3",
          name: "Block 3",
          build_req_id: "1",
          state: Block.State.value(:RUNNING)
        )
      ]
    )
  end

  def describe_many_response do
    Plumber.DescribeManyResponse.new(
      response_status: Plumber.ResponseStatus.new(code: 0),
      pipelines: [
        Pipeline.new(
          name: "My First Pipeline",
          ppl_id: "7e5ea0ae-3477-4d15-b3e9-768db905b9a2",
          project_id: "7e5ea0ae-3477-4d15-b3e9-768db905b9a2",
          branch_id: "7e5ea0ae-3477-4d15-b3e9-768db905b9a2",
          hook_id: "7e5ea0ae-3477-4d15-b3e9-768db905b9a2",
          branch_name: "master",
          commit_sha: "1234567",
          state: Plumber.Pipeline.State.value(:RUNNING),
          created_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 0},
          pending_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 0},
          queuing_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 0},
          running_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 0},
          stopping_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 0},
          done_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 0}
        ),
        Pipeline.new(
          name: "My Second Pipeline",
          ppl_id: "7e5ea0ae-3477-4d15-b3e9-768db905b9a2",
          project_id: "7e5ea0ae-3477-4d15-b3e9-768db905b9a2",
          branch_id: "7e5ea0ae-3477-4d15-b3e9-768db905b9a2",
          hook_id: "7e5ea0ae-3477-4d15-b3e9-768db905b9a2",
          branch_name: "master",
          commit_sha: "dffd88v",
          state: Plumber.Pipeline.State.value(:DONE),
          created_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 0},
          pending_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 0},
          queuing_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 0},
          running_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 0},
          stopping_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 0},
          done_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 3}
        )
      ]
    )
  end

  def pipeline(params \\ []) do
    alias InternalApi.Plumber.Pipeline

    defaults = [
      ppl_id: "3fd07895-e15b-43c4-8ee2-0ad18ce75507",
      project_id: "78114608-be8a-465a-b9cd-81970fb802c6",
      branch_name: "master",
      branch_id: "7e5ea0ae-3477-4d15-b3e9-768db905b9a2",
      name: "Pipeline Name",
      commit_sha: "1234567",
      hook_id: "21212121-be8a-465a-b9cd-81970fb802c6",
      created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_000),
      running_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_100),
      pending_at: Google.Protobuf.Timestamp.new(seconds: 0),
      queuing_at: Google.Protobuf.Timestamp.new(seconds: 0),
      stopping_at: Google.Protobuf.Timestamp.new(seconds: 0),
      done_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_220),
      state: Pipeline.State.value(:RUNNING),
      wf_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
      working_directory: ".semaphore",
      yaml_file_name: "semaphore.yml",
      switch_id: "a0420c87-1b5c-4c01-b937-61dab16142d1",
      compile_task_id: "",
      with_after_task: false,
      after_task_id: "",
      triggerer: Support.Factories.pipeline_triggerer()
    ]

    defaults |> Keyword.merge(params) |> InternalApi.Plumber.Pipeline.new()
  end

  def pending_pipeline(params \\ []) do
    defaults = [
      ppl_id: "78114608-be8a-465a-b9cd-81970fb802c6",
      project_id: "78114608-be8a-465a-b9cd-81970fb802c6",
      branch_name: "master",
      hook_id: "21212121-be8a-465a-b9cd-81970fb802c6",
      created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_259),
      done_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_300),
      state: Pipeline.State.value(:PENDING),
      triggerer: Support.Factories.pipeline_triggerer()
    ]

    defaults |> Keyword.merge(params) |> InternalApi.Plumber.Pipeline.new()
  end

  def running_pipeline(params \\ []) do
    defaults = [
      ppl_id: "78114608-be8a-465a-b9cd-81970fb802c6",
      project_id: "78114608-be8a-465a-b9cd-81970fb802c6",
      branch_name: "master",
      hook_id: "21212121-be8a-465a-b9cd-81970fb802c6",
      created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_259),
      running_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_260),
      pending_at: Google.Protobuf.Timestamp.new(seconds: 0),
      queuing_at: Google.Protobuf.Timestamp.new(seconds: 0),
      stopping_at: Google.Protobuf.Timestamp.new(seconds: 0),
      done_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_300),
      state: Pipeline.State.value(:RUNNING),
      triggerer: Support.Factories.pipeline_triggerer()
    ]

    defaults |> Keyword.merge(params) |> InternalApi.Plumber.Pipeline.new()
  end

  def finished_pipeline do
    pipeline(
      ppl_id: "3fd07895-e15b-43c4-8ee2-0ad18ce75508",
      done_at: Google.Protobuf.Timestamp.new(seconds: 1_522_757_858),
      state: Pipeline.State.value(:DONE),
      result: Pipeline.Result.value(:PASSED)
    )
  end
end
