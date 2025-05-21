defmodule Support.Stubs.Scheduler do
  require Logger
  alias Support.Stubs.{DB, Time, UUID}

  def init do
    DB.add_table(:schedulers, [:id, :project_id, :api_model])
    DB.add_table(:triggers, [:periodic_id, :project_id, :api_model])

    __MODULE__.Grpc.init()
  end

  def create(project, user, params \\ []) do
    periodic = build(project, user, params)

    DB.insert(:schedulers, %{
      id: periodic.id,
      project_id: periodic.project_id,
      api_model: periodic
    })

    periodic
  end

  def build(project, user, params) do
    alias InternalApi.PeriodicScheduler.Periodic

    defaults = [
      id: UUID.gen(),
      name: "Scheduler",
      project_id: project.id,
      recurring: true,
      branch: "master",
      at: "10 17 * * 1-5",
      pipeline_file: ".semaphore/semaphore.yml",
      requester_id: user.id,
      updated_at: Time.now() |> Map.take([:seconds, :nanos]),
      suspended: false,
      paused: false,
      pause_toggled_by: "",
      pause_toggled_at: Time.now() |> Map.take([:seconds, :nanos]),
      inserted_at: Time.now() |> Map.take([:seconds, :nanos]),
      parameters: []
    ]

    defaults |> Keyword.merge(params) |> Map.new() |> Util.Proto.deep_new!(Periodic)
  end

  def create_trigger(periodic, workflow, user, params \\ []) do
    trigger = build_trigger(periodic, workflow, user, params)

    DB.insert(:triggers, %{
      periodic_id: trigger.periodic_id,
      project_id: trigger.project_id,
      api_model: trigger
    })

    trigger
  end

  def build_trigger(periodic, workflow, user, params) do
    alias InternalApi.PeriodicScheduler.Trigger

    defaults = [
      triggered_at: Time.now(),
      project_id: periodic.project_id,
      branch: periodic.branch,
      pipeline_file: periodic.pipeline_file,
      scheduling_status: "passed",
      scheduled_workflow_id: workflow.wf_id,
      scheduled_at: Time.now(),
      error_description: "",
      run_now_requester_id: user.id,
      periodic_id: periodic.id
    ]

    defaults |> Keyword.merge(params) |> Trigger.new()
  end

  defmodule Grpc do
    alias Support.Stubs.{DB, Time}

    alias InternalApi.PeriodicScheduler.{
      DescribeResponse,
      HistoryResponse,
      LatestTriggersResponse,
      ListResponse,
      PauseResponse,
      RunNowResponse,
      UnpauseResponse
    }

    def init do
      GrpcMock.stub(SchedulerMock, :persist, &__MODULE__.persist/2)
      GrpcMock.stub(SchedulerMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(SchedulerMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(SchedulerMock, :delete, &__MODULE__.delete/2)
      GrpcMock.stub(SchedulerMock, :history, &__MODULE__.history/2)
      GrpcMock.stub(SchedulerMock, :pause, &__MODULE__.pause/2)
      GrpcMock.stub(SchedulerMock, :unpause, &__MODULE__.unpause/2)
      GrpcMock.stub(SchedulerMock, :run_now, &__MODULE__.run_now/2)
      GrpcMock.stub(SchedulerMock, :latest_triggers, &__MODULE__.latest_triggers/2)
    end

    def latest_triggers(req, _) do
      triggers =
        DB.all(:triggers)
        |> Enum.filter(fn o -> o.periodic_id in req.periodic_ids end)
        |> Enum.map(fn o -> o.api_model end)

      LatestTriggersResponse.new(triggers: triggers, status: status(:OK))
    end

    def pause(req, _) do
      db_record = DB.find(:schedulers, req.id)

      update_params = %{
        paused: true,
        pause_toggled_by: req.requester,
        pause_toggled_at: Time.now()
      }

      scheduler = Map.merge(db_record.api_model, update_params)

      new_db_record = Map.put(db_record, :api_model, scheduler)
      DB.update(:schedulers, new_db_record)

      PauseResponse.new(status: status(:OK))
    rescue
      e ->
        Logger.error(inspect(e))

        PauseResponse.new(status: status(:NOT_FOUND))
    end

    def unpause(req, _) do
      db_record = DB.find(:schedulers, req.id)

      update_params = %{
        paused: false,
        pause_toggled_by: req.requester,
        pause_toggled_at: Time.now()
      }

      scheduler = Map.merge(db_record.api_model, update_params)

      new_db_record = Map.put(db_record, :api_model, scheduler)
      DB.update(:schedulers, new_db_record)

      UnpauseResponse.new(status: status(:OK))
    rescue
      e ->
        Logger.error(inspect(e))

        UnpauseResponse.new(status: status(:NOT_FOUND))
    end

    def delete(req, _) do
      DB.delete(:schedulers, req.id)
      InternalApi.PeriodicScheduler.DeleteResponse.new(status: status(:OK))
    end

    def run_now(req, _) do
      scheduler = DB.find(:schedulers, req.id)
      user = %{id: req.requester}
      wf_id = DB.first(:workflows) |> Map.get(:id)
      workflow = %{wf_id: wf_id}

      trigger =
        Support.Stubs.Scheduler.create_trigger(scheduler.api_model, workflow, user,
          branch:
            if(req.branch == "",
              do: scheduler.api_model.branch,
              else: req.branch
            ),
          pipeline_file:
            if(req.pipeline_file == "",
              do: scheduler.api_model.pipeline_file,
              else: req.pipeline_file
            ),
          parameter_values: req.parameter_values || []
        )

      RunNowResponse.new(status: status(:OK), periodic: scheduler.api_model, triggers: [trigger])
    rescue
      e ->
        Logger.error(inspect(e))

        RunNowResponse.new(status: status(:NOT_FOUND))
    end

    @modifiable_fields ~w(name description recurring branch pipeline_file at parameters)a

    def persist(req, _) do
      model_from_req = periodic_from_req(req)

      if req.id != nil && req.id != "" do
        periodic = DB.find(:schedulers, req.id)
        new_fields = Map.take(model_from_req, @modifiable_fields)

        paused_related_fields =
          case req.state do
            0 ->
              %{}

            1 ->
              %{paused: false, paused_by: req.requester_id, paused_at: Time.now()}

            2 ->
              %{paused: true, paused_by: req.requester_id, paused_at: Time.now()}
          end

        model =
          periodic.api_model
          |> Map.merge(new_fields)
          |> Map.merge(paused_related_fields)

        DB.update(:schedulers, %{
          id: model.id,
          project_id: model.project_id,
          api_model: model
        })

        %InternalApi.PeriodicScheduler.PersistResponse{
          status: status(:OK),
          periodic: model
        }
      else
        model =
          Map.merge(model_from_req, %{
            id: UUID.gen(),
            project_id: req.project_id,
            requester_id: req.requester_id,
            inserted_at: Time.now(),
            updated_at: Time.now()
          })

        DB.upsert(:schedulers, %{
          id: model.id,
          project_id: model.project_id,
          api_model: model
        })

        %InternalApi.PeriodicScheduler.PersistResponse{
          status: status(:OK),
          periodic: model
        }
      end
    end

    def describe(req, _) do
      scheduler = DB.find(:schedulers, req.id)
      DescribeResponse.new(status: status(:OK), periodic: scheduler.api_model)
    rescue
      e ->
        Logger.error(inspect(e))

        DescribeResponse.new(status: status(:NOT_FOUND))
    end

    def history(req, _) do
      triggers =
        DB.all(:triggers)
        |> Stream.filter(&(&1.periodic_id == req.periodic_id))
        |> Stream.map(& &1.api_model)
        |> Enum.take(10)

      HistoryResponse.new(status: status(:OK), triggers: triggers)
    rescue
      e ->
        Logger.error(inspect(e))

        DescribeResponse.new(status: status(:NOT_FOUND))
    end

    def list(req, _) do
      page_no = if req.page < 1, do: 1, else: req.page
      page_size = if req.page_size < 1, do: 10, else: req.page_size

      name_filter = fn o ->
        if req.query != "" do
          query = String.downcase(req.query)
          name = String.downcase(o.api_model.name)
          String.contains?(name, query)
        else
          true
        end
      end

      schedulers =
        DB.all(:schedulers)
        |> Enum.filter(fn o -> o.api_model.project_id == req.project_id && name_filter.(o) end)
        |> Enum.map(fn o -> o.api_model end)

      page_schedulers =
        schedulers
        |> Enum.drop((page_no - 1) * req.page_size)
        |> Enum.take(page_size)

      total_pages =
        if rem(Enum.count(schedulers), page_size) == 0,
          do: div(Enum.count(schedulers), page_size),
          else: div(Enum.count(schedulers), page_size) + 1

      ListResponse.new(
        status: status(:OK),
        periodics: page_schedulers,
        page_number: page_no,
        page_size: Enum.count(page_schedulers),
        total_entries: Enum.count(schedulers),
        total_pages: total_pages
      )
    end

    defp status(code, message \\ "") do
      InternalApi.Status.new(
        code: Google.Rpc.Code.value(code),
        message: message
      )
    end

    defp periodic_from_req(req) do
      InternalApi.PeriodicScheduler.Periodic.new(
        id: req.id,
        name: req.name,
        description: req.description,
        recurring: req.recurring,
        requester_id: req.requester_id,
        branch: req.branch,
        pipeline_file: req.pipeline_file,
        at: req.at,
        parameters: req.parameters
      )
    end
  end
end
