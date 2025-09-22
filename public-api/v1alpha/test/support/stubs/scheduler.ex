defmodule Support.Stubs.Scheduler do
  require Logger
  alias Support.Stubs.{DB, Time}

  def init do
    DB.add_table(:schedulers, [:id, :project_id, :api_model])
    DB.add_table(:triggers, [:periodic_id, :project_id, :api_model])

    __MODULE__.Grpc.init()
  end

  def create(project_id, user_id, params \\ []) do
    periodic = build(project_id, user_id, params)

    DB.insert(:schedulers, %{
      id: periodic.id,
      project_id: periodic.project_id,
      api_model: periodic
    })

    periodic
  end

  def build(project_id, user_id, params) do
    alias InternalApi.PeriodicScheduler.Periodic

    defaults = [
      id: UUID.uuid4(),
      name: "Scheduler",
      project_id: project_id,
      reference: "refs/heads/master",
      at: "* * * * *",
      pipeline_file: ".semaphore/semaphore.yml",
      requester_id: user_id,
      updated_at: Time.now(),
      suspended: false,
      paused: false,
      pause_toggled_by: "",
      pause_toggled_at: Time.now(),
      inserted_at: Time.now()
    ]

    defaults |> Keyword.merge(params) |> Periodic.new()
  end

  def create_trigger(periodic, workflow_id, user_id, params \\ []) do
    trigger = build_trigger(periodic, workflow_id, user_id, params)

    DB.insert(:triggers, %{
      periodic_id: trigger.periodic_id,
      project_id: trigger.project_id,
      api_model: trigger
    })

    trigger
  end

  def build_trigger(periodic, workflow_id, user_id, params) do
    alias InternalApi.PeriodicScheduler.Trigger

    defaults = [
      triggered_at: Time.now(),
      project_id: periodic.project_id,
      reference: params[:reference] || periodic.reference,
      pipeline_file: params[:pipeline_file] || periodic.pipeline_file,
      parameter_values: params[:parameter_values] || [],
      scheduling_status: "passed",
      scheduled_workflow_id: workflow_id,
      scheduled_at: Time.now(),
      error_description: "",
      run_now_requester_id: user_id,
      periodic_id: periodic.id
    ]

    defaults |> Keyword.merge(params) |> Trigger.new()
  end

  defmodule Grpc do
    alias Support.Stubs.{DB, Time}

    alias InternalApi.PeriodicScheduler.{
      DescribeResponse,
      ListResponse
    }

    def init do
      GrpcMock.stub(SchedulerMock, :apply, &__MODULE__.apply/2)
      GrpcMock.stub(SchedulerMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(SchedulerMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(SchedulerMock, :delete, &__MODULE__.delete/2)
      GrpcMock.stub(SchedulerMock, :get_project_id, &__MODULE__.get_project_id/2)
      GrpcMock.stub(SchedulerMock, :run_now, &__MODULE__.run_now/2)
    end

    def delete(req, _) do
      DB.delete(:schedulers, req.id)
      DB.delete(:triggers, fn t -> t.periodic_id == req.id end)
      InternalApi.PeriodicScheduler.DeleteResponse.new(status: status(:OK))
    end

    def get_project_id(req, _) do
      case DB.find(:schedulers, req.periodic_id) do
        nil ->
          case DB.filter(:projects, org_id: req.organization_id, name: req.project_name) do
            [] ->
              InternalApi.PeriodicScheduler.GetProjectIdResponse.new(
                status: status(:NOT_FOUND, "Project not found")
              )

            [project | _] ->
              InternalApi.PeriodicScheduler.GetProjectIdResponse.new(
                status: status(:OK),
                project_id: project.id
              )
          end

        scheduler ->
          InternalApi.PeriodicScheduler.GetProjectIdResponse.new(
            status: status(:OK),
            project_id: scheduler.project_id
          )
      end
    end

    def run_now(req, _) do
      if req.reference == "refs/heads/RESOURCE_EXHAUSTED" do
        InternalApi.PeriodicScheduler.RunNowResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:RESOURCE_EXHAUSTED),
              message: "RESOURCE_EXHAUSTED message from server"
            )
        )
      else
        run_now_(req)
      end
    end

    def run_now_(req) do
      case DB.find(:schedulers, req.id) do
        nil ->
          InternalApi.PeriodicScheduler.RunNowResponse.new(
            status: status(:NOT_FOUND, "Periodic not found")
          )

        scheduler ->
          trigger =
            Support.Stubs.Scheduler.create_trigger(
              scheduler.api_model,
              UUID.uuid4(),
              req.requester,
              reference: req.reference,
              pipeline_file: req.pipeline_file,
              parameter_values: req.parameter_values
            )

          triggers =
            DB.find_all_by(:triggers, :periodic_id, req.id)
            |> Enum.map(fn trigger -> trigger.api_model end)

          InternalApi.PeriodicScheduler.RunNowResponse.new(
            status: status(:OK),
            periodic: scheduler.api_model,
            triggers: triggers,
            trigger: trigger
          )
      end
    end

    def apply(req, _) do
      periodic = extract_yaml(req)

      if periodic.id != nil do
        DB.update(:schedulers, %{
          id: periodic.id,
          project_id: periodic.project_id,
          api_model: periodic
        })

        InternalApi.PeriodicScheduler.ApplyResponse.new(
          status: status(:OK),
          id: periodic.id
        )
      else
        periodic_id = UUID.uuid4()

        DB.insert(:schedulers, %{
          id: periodic_id,
          project_id: UUID.uuid4(),
          api_model: periodic
        })

        InternalApi.PeriodicScheduler.ApplyResponse.new(
          status: status(:OK),
          id: periodic_id
        )
      end
    end

    def describe(req, _) do
      scheduler = DB.find(:schedulers, req.id)

      triggers =
        DB.find_all_by(:triggers, :periodic_id, req.id)
        |> Enum.map(fn trigger -> trigger.api_model end)

      DescribeResponse.new(status: status(:OK), periodic: scheduler.api_model, triggers: triggers)
    rescue
      e ->
        Logger.error(inspect(e))

        DescribeResponse.new(status: status(:NOT_FOUND))
    end

    def list(req, _) do
      schedulers =
        DB.all(:schedulers)
        |> Enum.filter(fn o -> o.api_model.project_id == req.project_id end)
        |> Enum.map(fn o -> o.api_model end)

      ListResponse.new(
        status: status(:OK),
        periodics: schedulers,
        page_number: 1,
        page_size: 30,
        total_entries: Enum.count(schedulers),
        total_pages: 1
      )
    end

    defp status(code, message \\ "") do
      InternalApi.Status.new(
        code: Google.Rpc.Code.value(code),
        message: message
      )
    end

    defp extract_yaml(req) do
      {:ok, data} = YamlElixir.read_from_string(req.yml_definition)
      metadata = data["metadata"]
      spec = data["spec"]

      reference = if data["apiVersion"] == "v1.2", do: spec["reference"], else: spec["branch"]

      InternalApi.PeriodicScheduler.Periodic.new(
        id: metadata["id"],
        name: metadata["name"],
        project_id: "",
        reference: reference,
        at: spec["at"],
        pipeline_file: spec["pipeline_file"],
        requester_id: req.requester_id,
        updated_at: Time.now()
      )
    end
  end
end
