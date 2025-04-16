defmodule Support.Stubs.Workflow do
  alias Support.Stubs.{Artifacthub, DB, UUID, Velocity}

  @type workflow_stub_t :: %{
          id: Ecto.UUID.t(),
          hook_id: Ecto.UUID.t(),
          api_model: InternalApi.PlumberWF.WorkflowDetails.t()
        }

  def init do
    DB.add_table(:workflows, [:id, :hook_id, :api_model])

    __MODULE__.Grpc.init()
  end

  def create(hook, user, params \\ []) do
    api_model = build_api_model(hook, user, params)

    DB.insert(:workflows, %{
      id: api_model.wf_id,
      hook_id: hook.id,
      api_model: api_model
    })
  end

  def add_report(workflow_id, filename \\ "reports/wf_report.md") do
    Artifacthub.create(workflow_id,
      path: ".semaphore/REPORT.md",
      scope: "workflows",
      url:
        Path.join(
          Application.get_env(:front, :artifact_host),
          filename
        )
    )
  end

  @spec with_summary(workflow_stub_t(),
          project_id: String.t(),
          pipeline_id: String.t(),
          summary: keyword()
        ) :: any()
  def with_summary(workflow, params \\ []) do
    params =
      [
        project_id: workflow.api_model.project_id,
        pipeline_id: workflow.api_model.initial_ppl_id
      ]
      |> Keyword.merge(params)

    Velocity.create_pipeline_summary(params)
  end

  @spec add_artifact(workflow_stub_t(), url: String.t(), path: String.t()) :: any()
  def add_artifact(workflow, params \\ []) do
    params = Keyword.merge(params, scope: "workflows")

    Artifacthub.create(workflow.id, params)
  end

  def build_api_model(hook, user, params \\ []) do
    defaults = [
      wf_id: UUID.gen(),
      initial_ppl_id: UUID.gen(),
      created_at: DateTime.utc_now() |> DateTime.to_unix()
    ]

    params = defaults |> Keyword.merge(params)

    InternalApi.PlumberWF.WorkflowDetails.new(
      wf_id: params[:wf_id],
      initial_ppl_id: params[:initial_ppl_id],
      project_id: hook.project_id,
      hook_id: hook.id,
      requester_id: user.id,
      branch_id: hook.branch_id,
      branch_name: "master",
      commit_sha: hook.api_model.head_commit_sha,
      created_at: Google.Protobuf.Timestamp.new(seconds: params[:created_at]),
      triggered_by: 0,
      rerun_of: ""
    )
  end

  defmodule Grpc do
    alias Support.Stubs.DB

    def init do
      GrpcMock.stub(WorkflowMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(WorkflowMock, :describe_many, &__MODULE__.describe_many/2)
      GrpcMock.stub(WorkflowMock, :get_path, &__MODULE__.get_path/2)
      GrpcMock.stub(WorkflowMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(WorkflowMock, :list_keyset, &__MODULE__.list_keyset/2)
      GrpcMock.stub(WorkflowMock, :list_latest_workflows, &__MODULE__.list_latest/2)
      GrpcMock.stub(WorkflowMock, :reschedule, &__MODULE__.reschedule/2)
    end

    def get_path(req, _) do
      alias InternalApi.PlumberWF.GetPathResponse, as: Response

      path =
        DB.find_all_by(:pipelines, :id, req.last_ppl_id)
        |> Enum.map(fn p -> [ppl_id: p.id, switch_id: p.api_model.switch_id] end)
        |> Enum.map(fn p -> Response.PathElement.new(p) end)

      Response.new(path: path)
    end

    def list(req, _) do
      alias InternalApi.PlumberWF.ListResponse, as: Response

      wfs =
        DB.all(:workflows)
        |> Enum.filter(fn w -> w.api_model.project_id == req.project_id end)
        |> DB.extract(:api_model)

      Response.new(workflows: wfs)
    end

    def describe(req, _) do
      alias InternalApi.PlumberWF.DescribeResponse

      case find(req) do
        {:ok, workflow} ->
          DescribeResponse.new(status: InternalApi.Status.new(), workflow: workflow.api_model)

        {:error, nil} ->
          DescribeResponse.new(
            status: InternalApi.Status.new(code: Google.Rpc.Code.value(:NOT_FOUND)),
            workflow: nil
          )
      end
    end

    def describe_many(req, _) do
      alias InternalApi.PlumberWF.DescribeManyResponse

      workflows =
        DB.all(:workflows)
        |> Stream.filter(&Enum.member?(req.wf_ids, &1.id))
        |> Enum.into([], & &1.api_model)

      DescribeManyResponse.new(status: InternalApi.Status.new(), workflows: workflows)
    end

    def list_latest(req, _) do
      alias InternalApi.PlumberWF.ListLatestWorkflowsResponse, as: Response

      wfs =
        DB.all(:workflows)
        |> Enum.filter(fn w -> w.api_model.project_id == req.project_id end)
        |> DB.extract(:api_model)

      Response.new(workflows: wfs)
    end

    def list_keyset(_req, _) do
      wfs = DB.all(:workflows) |> DB.extract(:api_model)

      InternalApi.PlumberWF.ListKeysetResponse.new(
        workflows: wfs,
        next_page_token: "",
        previous_page_token: "",
        status: ok()
      )
    end

    def reschedule(_req, _) do
      hook = DB.last(:hooks)
      user = DB.last(:users)

      new_workflow = Support.Stubs.Workflow.create(hook, user)

      InternalApi.PlumberWF.ScheduleResponse.new(
        wf_id: new_workflow.id,
        ppl_id: "",
        status: ok()
      )
    end

    defp find(req) do
      case DB.find_by(:workflows, :id, req.wf_id) do
        nil ->
          {:error, nil}

        workflow ->
          {:ok, workflow}
      end
    end

    def ok do
      InternalApi.Status.new(code: Google.Rpc.Code.value(:OK), message: "")
    end
  end
end
