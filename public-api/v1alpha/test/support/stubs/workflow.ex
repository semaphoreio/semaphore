defmodule Support.Stubs.Workflow do
  alias Support.Stubs.DB

  require Logger

  def init do
    DB.add_table(:workflows, [:id, :hook_id, :api_model])

    __MODULE__.Grpc.init()
  end

  def create(hook, user_id, params \\ []) do
    api_model = build_api_model(hook, user_id, params)

    DB.insert(:workflows, %{
      id: api_model.wf_id,
      hook_id: hook.id,
      api_model: api_model
    })
  end

  def build_api_model(hook, user_id, params \\ []) do
    defaults = [
      wf_id: UUID.uuid4(),
      initial_ppl_id: UUID.uuid4(),
      organization_id: "test_org",
      created_at: DateTime.utc_now() |> DateTime.to_unix(),
      branch_name: "master"
    ]

    params = defaults |> Keyword.merge(params)

    InternalApi.PlumberWF.WorkflowDetails.new(
      wf_id: params[:wf_id],
      initial_ppl_id: params[:initial_ppl_id],
      organization_id: params[:organization_id],
      project_id: hook.project_id,
      hook_id: hook.id,
      requester_id: user_id,
      branch_id: hook.branch_id,
      branch_name: params[:branch_name],
      commit_sha: UUID.uuid4(),
      created_at: Google.Protobuf.Timestamp.new(seconds: params[:created_at]),
      triggered_by: params[:triggered_by] || 0,
      rerun_of: ""
    )
  end

  defmodule Grpc do
    alias Support.Stubs.DB

    def init do
      GrpcMock.stub(WorkflowMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(WorkflowMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(WorkflowMock, :schedule, &__MODULE__.schedule/2)
      GrpcMock.stub(WorkflowMock, :reschedule, &__MODULE__.reschedule/2)
      GrpcMock.stub(WorkflowMock, :terminate, &__MODULE__.terminate/2)
    end

    def terminate(req, _) do
      ppl_count = DB.filter(:pipelines, wf_id: req.wf_id) |> Enum.count()

      Logger.info("Found #{ppl_count} pipelines.")

      InternalApi.PlumberWF.TerminateResponse.new(
        status:
          InternalApi.Status.new(
            code: Google.Rpc.Code.value(:OK),
            message: "Termination started for " <> Integer.to_string(ppl_count) <> " pipelines."
          )
      )
    end

    def list(req, _) do
      alias InternalApi.PlumberWF.ListResponse, as: Response

      wfs =
        DB.all(:workflows)
        |> Enum.filter(fn w -> w.api_model.project_id == req.project_id end)
        |> DB.extract(:api_model)
        |> filter(req)
        |> Enum.sort_by(fn w -> w.created_at.seconds end, &>=/2)

      pages =
        wfs
        |> Enum.chunk_every(req.page_size)

      page = pages |> Enum.at(req.page - 1)

      Response.new(
        workflows: page,
        page_number: req.page,
        page_size: req.page_size,
        total_entries: Enum.count(wfs),
        total_pages: Enum.count(pages)
      )
    end

    defp filter(workflows, req) do
      if req.branch_name != "" do
        workflows
        |> Enum.filter(fn w -> w.branch_name == req.branch_name end)
      else
        workflows
      end
    end

    def describe(req, _) do
      alias InternalApi.PlumberWF.DescribeResponse

      case find(req) do
        {:ok, workflow} ->
          DescribeResponse.new(status: InternalApi.Status.new(), workflow: workflow.api_model)

        {:error, nil} ->
          DescribeResponse.new(
            status: InternalApi.Status.new(code: Google.Rpc.Code.value(:FAILED_PRECONDITION)),
            workflow: nil
          )
      end
    end

    def schedule(req, _) do
      case req.project_id do
        "invalid_arg" ->
          InternalApi.PlumberWF.ScheduleResponse.new(
            status:
              InternalApi.Status.new(
                code: Google.Rpc.Code.value(:INVALID_ARGUMENT),
                message: "Invalid argument"
              )
          )

        "project_deleted" ->
          InternalApi.PlumberWF.ScheduleResponse.new(
            status:
              InternalApi.Status.new(
                code: Google.Rpc.Code.value(:FAILED_PRECONDITION),
                message: "Failed precondition"
              )
          )

        "resource_exhausted" ->
          InternalApi.PlumberWF.ScheduleResponse.new(
            status:
              InternalApi.Status.new(
                code: Google.Rpc.Code.value(:RESOURCE_EXHAUSTED),
                message: "Resource exhausted"
              )
          )

        "internal_error" ->
          raise GRPC.RPCError, status: GRPC.Status.internal(), message: "Internal error"

        _ ->
          user_id = UUID.uuid4()
          branch = Support.Stubs.Branch.create(%{id: req.project_id})
          hook = Support.Stubs.Hook.create(branch)
          new_workflow = Support.Stubs.Workflow.create(hook, user_id)
          new_pipeline = Support.Stubs.Pipeline.create(new_workflow)

          InternalApi.PlumberWF.ScheduleResponse.new(
            wf_id: new_workflow.id,
            ppl_id: new_pipeline.id,
            status: ok()
          )
      end
    end

    # TODO: needs to change, since we don't have :hooks and :users
    def reschedule(_req, _) do
      user_id = UUID.uuid4()

      hook = %{
        id: UUID.uuid4(),
        project_id: UUID.uuid4(),
        branch_id: UUID.uuid4()
      }

      new_workflow = Support.Stubs.Workflow.create(hook, user_id)

      InternalApi.PlumberWF.ScheduleResponse.new(
        wf_id: new_workflow.id,
        ppl_id: UUID.uuid4(),
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
