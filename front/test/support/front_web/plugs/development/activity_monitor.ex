defmodule FrontWeb.Plugs.Development.ActivityMonitor do
  alias InternalApi.Plumber.DescribeTopologyResponse
  alias InternalApi.Plumber.Pipeline
  alias Support.Factories

  alias InternalApi.Plumber.{
    DescribeTopologyResponse,
    Pipeline
  }

  def init(options), do: options

  def call(conn, _opts) do
    stub()

    conn
  end

  def stub do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    FunRegistry.clear!()

    # Activity Monitor specific pages

    active_pipelines = active_pipelines()
    active_jobs = jobs()

    active_debug_session =
      InternalApi.ServerFarm.Job.ListDebugSessionsResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))
      )

    GrpcMock.stub(PipelineMock, :list_activity, active_pipelines)
    GrpcMock.stub(InternalJobMock, :list_debug_sessions, active_debug_session)

    accessible_projects =
      InternalApi.Projecthub.ListResponse.new(
        metadata: Support.Factories.response_meta(:OK),
        projects:
          Enum.map(active_pipelines.pipelines, fn p ->
            Support.Factories.listed_project(id: p.project_id)
          end),
        pagination:
          InternalApi.Projecthub.PaginationResponse.new(
            total_pages: 3,
            total_entries: 20
          )
      )

    GrpcMock.stub(PipelineMock, :list_activity, active_pipelines)
    GrpcMock.stub(InternalJobMock, :list, active_jobs)

    GrpcMock.stub(ProjecthubMock, :list, accessible_projects)
    GrpcMock.stub(InternalJobMock, :list_debug_sessions, active_debug_session)
    GrpcMock.stub(PipelineMock, :terminate, Factories.Pipeline.terminate_response())

    GrpcMock.stub(SelfHostedAgentsMock, :list, self_hosted_agent_types())

    GrpcMock.stub(
      RBACMock,
      :list_accessible_projects,
      InternalApi.RBAC.ListAccessibleProjectsResponse.new(
        project_ids: [Map.get(Support.Stubs.DB.first(:projects), :id)]
      )
    )
  end

  def self_hosted_agent_types do
    InternalApi.SelfHosted.ListResponse.new(
      agent_types: [
        InternalApi.SelfHosted.AgentType.new(
          name: "s1-small",
          total_agent_count: 4
        ),
        InternalApi.SelfHosted.AgentType.new(
          name: "s1-medium",
          total_agent_count: 0
        ),
        InternalApi.SelfHosted.AgentType.new(
          name: "s1-large",
          total_agent_count: 10
        )
      ]
    )
  end

  def active_pipelines do
    InternalApi.Plumber.ListActivityResponse.new(
      status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
      pipelines: [
        InternalApi.Plumber.ActivePipeline.new(
          name: "Build & Test Queuing",
          commit_message: "Release Activity Monitor",
          created_at: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1},
          project_id: Map.get(Support.Stubs.DB.first(:projects), :id),
          ppl_id: Ecto.UUID.generate(),
          requester_id: Map.get(Support.Stubs.DB.first(:users), :id),
          state: InternalApi.Plumber.Pipeline.State.value(:QUEUING),
          blocks: [
            InternalApi.Plumber.BlockDetails.new(
              jobs: [
                InternalApi.Plumber.BlockDetails.JobDetails.new(
                  index: 0,
                  name: "Rspec",
                  status: "scheduled"
                ),
                InternalApi.Plumber.BlockDetails.JobDetails.new(
                  index: 1,
                  name: "RSpec",
                  status: "scheduled"
                )
              ]
            )
          ]
        ),
        InternalApi.Plumber.ActivePipeline.new(
          name: "Build & Test",
          commit_message: "Release Activity Monitor",
          created_at: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1},
          project_id: Map.get(Support.Stubs.DB.first(:projects), :id),
          ppl_id: Ecto.UUID.generate(),
          requester_id: Map.get(Support.Stubs.DB.first(:users), :id),
          state: InternalApi.Plumber.Pipeline.State.value(:RUNNING),
          blocks: [
            InternalApi.Plumber.BlockDetails.new(
              jobs: [
                InternalApi.Plumber.BlockDetails.JobDetails.new(
                  index: 0,
                  name: "Rspec",
                  status: "scheduled"
                ),
                InternalApi.Plumber.BlockDetails.JobDetails.new(
                  index: 1,
                  name: "RSpec",
                  status: "scheduled"
                )
              ]
            )
          ]
        ),
        InternalApi.Plumber.ActivePipeline.new(
          name: "Build & Test 3",
          commit_message: "Release Activity Monitor",
          created_at: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1},
          project_id: Map.get(Support.Stubs.DB.first(:projects), :id),
          ppl_id: Ecto.UUID.generate(),
          requester_id: Map.get(Support.Stubs.DB.first(:users), :id),
          state: InternalApi.Plumber.Pipeline.State.value(:RUNNING),
          blocks: [
            InternalApi.Plumber.BlockDetails.new(
              jobs: [
                InternalApi.Plumber.BlockDetails.JobDetails.new(
                  index: 0,
                  name: "Rspec",
                  status: "scheduled"
                ),
                InternalApi.Plumber.BlockDetails.JobDetails.new(
                  index: 1,
                  name: "RSpec",
                  status: "scheduled"
                )
              ]
            )
          ]
        )
      ]
    )
  end

  def running_pipelines do
    active_pipelines().pipelines
    |> Enum.filter(fn p ->
      p.state == InternalApi.Plumber.Pipeline.State.value(:RUNNING)
    end)
  end

  def jobs do
    InternalApi.ServerFarm.Job.ListResponse.new(
      status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
      jobs: create_jobs(running_pipelines())
    )
  end

  def create_jobs(pipelines) do
    Enum.map(pipelines, fn pipeline ->
      Enum.map(pipeline.blocks, fn block ->
        Enum.map(block.jobs, fn job ->
          [
            create_job(
              ppl_id: pipeline.ppl_id,
              name: job.name,
              index: job.index,
              state: InternalApi.ServerFarm.Job.Job.State.value(:ENQUEUED),
              project_id: pipeline.project_id
            ),
            create_job(
              ppl_id: pipeline.ppl_id,
              name: job.name,
              index: job.index,
              state: InternalApi.ServerFarm.Job.Job.State.value(:STARTED),
              project_id: pipeline.project_id
            ),
            create_job(
              ppl_id: pipeline.ppl_id,
              name: job.name,
              index: job.index,
              state: InternalApi.ServerFarm.Job.Job.State.value(:FINISHED),
              project_id: pipeline.project_id
            ),
            create_job(
              ppl_id: pipeline.ppl_id,
              name: job.name,
              index: job.index,
              state: InternalApi.ServerFarm.Job.Job.State.value(:ENQUEUED),
              project_id: pipeline.project_id,
              machine_type: "s1-small",
              self_hosted: true
            ),
            create_job(
              ppl_id: pipeline.ppl_id,
              name: job.name,
              index: job.index,
              state: InternalApi.ServerFarm.Job.Job.State.value(:STARTED),
              project_id: pipeline.project_id,
              machine_type: "s1-small",
              self_hosted: true
            ),
            create_job(
              ppl_id: pipeline.ppl_id,
              name: job.name,
              index: job.index,
              state: InternalApi.ServerFarm.Job.Job.State.value(:SCHEDULED),
              project_id: pipeline.project_id,
              machine_type: "s1-small",
              self_hosted: true
            ),
            create_job(
              ppl_id: pipeline.ppl_id,
              name: job.name,
              index: job.index,
              state: InternalApi.ServerFarm.Job.Job.State.value(:FINISHED),
              project_id: pipeline.project_id,
              machine_type: "s1-small",
              self_hosted: true
            )
          ]
        end)
      end)
    end)
    |> List.flatten()
  end

  def create_job(params \\ []) do
    defaults = [
      id: Ecto.UUID.generate(),
      project_id: Map.get(Support.Stubs.DB.first(:projects), :id),
      branch_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
      hook_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
      name: "RSpec 342/708",
      ppl_id: "78114608-be8a-465a-b9cd-81970fb802c6",
      timeline:
        InternalApi.ServerFarm.Job.Job.Timeline.new(
          created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_259),
          enqueued_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_260),
          started_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_261),
          finished_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_262)
        ),
      state: InternalApi.ServerFarm.Job.Job.State.value(:FINISHED),
      result: InternalApi.ServerFarm.Job.Job.Result.value(:PASSED),
      failure_reason: "",
      build_server: "127.0.0.1",
      machine_type: "e1-standard-2",
      stopped_by: Support.Stubs.User.default_user_id()
    ]

    InternalApi.ServerFarm.Job.Job.new(Keyword.merge(defaults, params))
  end

  def hook_describe do
    FunRegistry.set!(
      Support.FakeServices.RepoProxyService,
      :describe,
      Factories.RepoProxy.describe_response()
    )
  end

  def workflow_describe do
    workflow_response = Factories.Workflow.describe_response()
    FunRegistry.set!(Support.FakeServices.WorkflowService, :describe, workflow_response)
  end

  def workflow_reschedule do
    FunRegistry.set!(
      Support.FakeServices.WorkflowService,
      :reschedule,
      Factories.Workflow.reschedule_response()
    )
  end

  def branch_describe do
    GrpcMock.stub(
      BranchMock,
      :describe,
      Support.Factories.branch_describe_response()
    )
  end

  def pipeline_terminate do
    GrpcMock.stub(PipelineMock, :terminate, Factories.Pipeline.terminate_response())
  end

  def pipeline_describe_topology do
    GrpcMock.stub(
      PipelineMock,
      :describe_topology,
      %DescribeTopologyResponse{
        blocks: [
          %DescribeTopologyResponse.Block{
            name: "block 1",
            jobs: ["job 1", "job 2", "job 3"],
            dependencies: []
          }
        ],
        after_pipeline: %DescribeTopologyResponse.AfterPipeline{jobs: []},
        status: %InternalApi.Plumber.ResponseStatus{code: 0, message: ""}
      }
    )
  end

  def pipeline_describe do
    pipelines = [
      %{
        id: "running",
        state: :RUNNING,
        result: :PASSED,
        switch_id: "43e929b5-06de-451c-8e52-829cd252d7f9"
      },
      %{
        id: "passed",
        state: :DONE,
        result: :PASSED,
        switch_id: "43e929b5-06de-451c-8e52-829cd252d7f9"
      },
      %{
        id: "failed",
        state: :DONE,
        result: :FAILED,
        switch_id: "43e929b5-06de-451c-8e52-829cd252d7f9"
      },
      %{
        id: "stopped",
        state: :DONE,
        result: :STOPPED,
        switch_id: "43e929b5-06de-451c-8e52-829cd252d7f9"
      },
      %{
        id: "queued",
        state: :QUEUED,
        result: :PASSED,
        switch_id: ""
      }
    ]

    GrpcMock.stub(PipelineMock, :describe, fn req, _stream ->
      Enum.find(pipelines, fn pipeline -> pipeline.id == req.ppl_id end)
      |> Factories.Pipeline.describe_response()
    end)
  end

  def pipeline_describe_many do
    GrpcMock.stub(PipelineMock, :describe_many, fn _req, _stream ->
      InternalApi.Plumber.DescribeManyResponse.new(
        response_status:
          InternalApi.Plumber.ResponseStatus.new(
            code: InternalApi.Plumber.ResponseStatus.ResponseCode.value(:OK)
          ),
        pipelines: [
          Factories.Pipeline.pipeline(
            ppl_id: "running",
            state: Pipeline.State.value(:RUNNING),
            switch_id: "43e929b5-06de-451c-8e52-829cd252d7f9"
          ),
          Factories.Pipeline.pipeline(
            ppl_id: "queuing",
            state: Pipeline.State.value(:QUEUING),
            switch_id: "43e929b5-06de-451c-8e52-829cd252d7f9"
          ),
          Factories.Pipeline.pipeline(
            ppl_id: "passed",
            state: Pipeline.State.value(:DONE),
            result: Pipeline.Result.value(:PASSED),
            switch_id: "",
            error_description: "Foo"
          ),
          Factories.Pipeline.pipeline(
            ppl_id: "failed",
            state: Pipeline.State.value(:DONE),
            result: Pipeline.Result.value(:FAILED),
            switch_id: "",
            error_description: "Foo"
          ),
          Factories.Pipeline.pipeline(
            ppl_id: "stopped",
            state: Pipeline.State.value(:DONE),
            result: Pipeline.Result.value(:STOPPED),
            switch_id: "",
            terminated_by: "8d76e1a5-b1db-45db-818e-ecab3c9a9904"
          )
        ]
      )
    end)
  end

  def pipeline_list do
    GrpcMock.stub(PipelineMock, :list, fn _req, _stream ->
      InternalApi.Plumber.ListResponse.new(
        pipelines: [
          Factories.Pipeline.pipeline(
            id: "running",
            state: Pipeline.State.value(:RUNNING),
            switch_id: "43e929b5-06de-451c-8e52-829cd252d7f9"
          ),
          Factories.Pipeline.pipeline(
            id: "failed",
            state: Pipeline.State.value(:DONE),
            result: Pipeline.Result.value(:FAILED),
            switch_id: ""
          ),
          Factories.Pipeline.pipeline(
            id: "stopped",
            state: Pipeline.State.value(:DONE),
            result: Pipeline.Result.value(:STOPPED),
            switch_id: "",
            terminated_by: "8d76e1a5-b1db-45db-818e-ecab3c9a9904"
          ),
          Factories.Pipeline.pipeline(
            id: "passed",
            state: Pipeline.State.value(:DONE),
            result: Pipeline.Result.value(:PASSED),
            switch_id: ""
          )
        ],
        response_status:
          InternalApi.Plumber.ResponseStatus.new(
            code: InternalApi.Plumber.ResponseStatus.ResponseCode.value(:OK)
          )
      )
    end)
  end
end
