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

    params_with_defaults =
      [
        id: UUID.uuid4(),
        name: "Scheduler",
        project_id: project_id,
        branch: "master",
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
      |> Keyword.merge(params)

    struct(Periodic, params_with_defaults)
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

    params_with_defaults =
      [
        triggered_at: Time.now(),
        project_id: periodic.project_id,
        branch: periodic.branch,
        pipeline_file: periodic.pipeline_file,
        scheduling_status: "passed",
        scheduled_workflow_id: workflow_id,
        scheduled_at: Time.now(),
        error_description: "",
        run_now_requester_id: user_id,
        periodic_id: periodic.id,
        parameter_values: []
      ]
      |> Keyword.merge(params)

    struct(Trigger, params_with_defaults)
  end

  defmodule Grpc do
    alias Support.Stubs.{DB, Time}

    alias InternalApi.PeriodicScheduler.{
      DescribeResponse,
      ListResponse,
      ListKeysetResponse
    }

    def init do
      GrpcMock.stub(SchedulerMock, :apply, &__MODULE__.apply/2)
      GrpcMock.stub(SchedulerMock, :persist, &__MODULE__.persist/2)
      GrpcMock.stub(SchedulerMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(SchedulerMock, :list_keyset, &__MODULE__.list_keyset/2)
      GrpcMock.stub(SchedulerMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(SchedulerMock, :delete, &__MODULE__.delete/2)
      GrpcMock.stub(SchedulerMock, :run_now, &__MODULE__.run_now/2)
      GrpcMock.stub(SchedulerMock, :get_project_id, &__MODULE__.get_project_id/2)
    end

    def delete(req, _) do
      case DB.find(:schedulers, req.id) do
        nil ->
          %InternalApi.PeriodicScheduler.DeleteResponse{
            status: status(:NOT_FOUND)
          }

        _periodic ->
          DB.delete(:schedulers, req.id)
          DB.delete(:triggers, fn t -> t.periodic_id == req.id end)
          %InternalApi.PeriodicScheduler.DeleteResponse{status: status(:OK)}
      end
    end

    def get_project_id(req, _) do
      case DB.find(:schedulers, req.periodic_id) do
        nil ->
          %InternalApi.PeriodicScheduler.GetProjectIdResponse{
            status: status(:OK),
            project_id: UUID.uuid4()
          }

        scheduler ->
          %InternalApi.PeriodicScheduler.GetProjectIdResponse{
            status: status(:OK),
            project_id: scheduler.project_id
          }
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

        %InternalApi.PeriodicScheduler.ApplyResponse{
          status: status(:OK),
          id: periodic.id
        }
      else
        periodic_id = UUID.uuid4()

        DB.insert(:schedulers, %{
          id: periodic_id,
          project_id: UUID.uuid4(),
          api_model: periodic
        })

        %InternalApi.PeriodicScheduler.ApplyResponse{
          status: status(:OK),
          id: periodic_id
        }
      end
    end

    @modifiable_fields ~w(name description recurring branch pipeline_file at parameters)a

    def persist(req, _) do
      model_from_req = periodic_from_req(req)

      if req.id != nil && req.id != "" do
        periodic = DB.find(:schedulers, req.id)
        new_fields = Map.take(model_from_req, @modifiable_fields)

        paused_related_fields =
          case req.state do
            :UNCHANGED ->
              %{}

            :ACTIVE ->
              %{paused: false, paused_by: req.requester_id, paused_at: Time.now()}

            :PAUSED ->
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
            id: UUID.uuid4(),
            project_id: UUID.uuid4(),
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

      triggers =
        DB.find_all_by(:triggers, :periodic_id, req.id)
        |> Enum.map(fn trigger -> trigger.api_model end)

      %DescribeResponse{status: status(:OK), periodic: scheduler.api_model, triggers: triggers}
    rescue
      e ->
        Logger.error(inspect(e))

        %DescribeResponse{status: status(:NOT_FOUND)}
    end

    def list(req, _) do
      schedulers =
        DB.all(:schedulers)
        |> Enum.filter(fn o ->
          if req.project_id != "" do
            o.project_id == req.project_id
          else
            true
          end
        end)
        |> Enum.map(fn o -> o.api_model end)

      total = Enum.count(schedulers)

      total_pages =
        if req.page_size != 0 do
          if rem(total, req.page_size) != 0 do
            div(total, req.page_size) + 1
          else
            div(total, req.page_size)
          end
        else
          0
        end

      %ListResponse{
        status: status(:OK),
        periodics:
          schedulers
          |> Enum.drop(min(req.page - 1, 0) * req.page_size)
          |> Enum.take(req.page_size),
        page_number: req.page,
        page_size: req.page_size,
        total_entries: total,
        total_pages: total_pages
      }
    end

    def list_keyset(req, _) do
      maybe_filter_project = fn schedulers, project_id ->
        if project_id != "" do
          Enum.filter(schedulers, fn o -> o.project_id == project_id end)
        else
          schedulers
        end
      end

      periodics =
        DB.all(:schedulers)
        |> maybe_filter_project.(req.project_id)
        |> Enum.sort_by(& &1.api_model.name)

      token_index = Enum.find_index(periodics, fn sch -> sch.id == req.page_token end) || 0

      page_start =
        case req.direction do
          :NEXT -> token_index
          :PREV -> max(token_index - req.page_size + 1, 0)
        end

      page_end =
        case req.direction do
          :NEXT -> min(page_start + req.page_size - 1, length(periodics) - 1)
          :PREV -> token_index
        end

      %ListKeysetResponse{
        status: status(:OK),
        periodics: periodics |> Enum.slice(page_start..page_end) |> Enum.map(& &1.api_model),
        next_page_token:
          if(page_end < length(periodics) - 1,
            do: periodics |> Enum.at(page_end + 1) |> Map.get(:id),
            else: ""
          ),
        prev_page_token:
          if(page_start > 0, do: periodics |> Enum.at(page_start - 1) |> Map.get(:id), else: ""),
        page_size: req.page_size
      }
    end

    def run_now(req, _) do
      case DB.find(:schedulers, req.id) do
        nil ->
          %InternalApi.PeriodicScheduler.RunNowResponse{
            status: status(:NOT_FOUND, "Scheduler not found")
          }

        periodic ->
          params =
            Enum.filter(
              [
                branch: if(req.branch != "", do: req.branch),
                pipeline_file: if(req.pipeline_file != "", do: req.pipeline_file),
                parameter_values: req.parameter_values
              ],
              &(elem(&1, 1) != nil)
            )

          trigger =
            Support.Stubs.Scheduler.create_trigger(
              periodic.api_model,
              UUID.uuid4(),
              req.requester,
              params
            )

          %InternalApi.PeriodicScheduler.RunNowResponse{
            status: status(:OK),
            periodic: periodic.api_model,
            triggers: [trigger]
          }
      end
    end

    defp status(code, message \\ "") do
      %InternalApi.Status{
        code: Google.Rpc.Code.value(code),
        message: message
      }
    end

    defp extract_yaml(req) do
      {:ok, data} = YamlElixir.read_from_string(req.yml_definition)
      metadata = data["metadata"]
      spec = data["spec"]

      %InternalApi.PeriodicScheduler.Periodic{
        id: metadata["id"],
        name: metadata["name"],
        project_id: "",
        branch: spec["branch"],
        at: spec["at"],
        pipeline_file: spec["pipeline_file"],
        requester_id: req.requester_id,
        updated_at: Time.now()
      }
    end

    defp periodic_from_req(req) do
      %InternalApi.PeriodicScheduler.Periodic{
        id: req.id,
        name: req.name,
        description: req.description,
        recurring: req.recurring,
        requester_id: req.requester_id,
        branch: req.branch,
        pipeline_file: req.pipeline_file,
        at: req.at,
        parameters: req.parameters
      }
    end
  end
end
