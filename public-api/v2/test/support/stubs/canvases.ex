defmodule Support.Stubs.Canvases do
  alias Support.Stubs.{DB, UUID}

  def init do
    DB.add_table(:canvases, [:id, :name, :org_id])
    DB.add_table(:stages, [:id, :name, :org_id, :canvas_id, :api_model])
    DB.add_table(:sources, [:id, :name, :org_id, :canvas_id])

    DB.add_table(:stage_events, [
      :id,
      :org_id,
      :canvas_id,
      :stage_id,
      :state,
      :state_reason,
      :source_id,
      :source_type,
      :approvals
    ])

    __MODULE__.Grpc.init()
  end

  def create_canvas(org, params \\ []) do
    defaults = [
      user_id: UUID.gen()
    ]

    params = defaults |> Keyword.merge(params)

    DB.insert(:canvases, %{
      id: UUID.gen(),
      name: params[:name],
      org_id: org.id
    })
  end

  def create_stage(org, canvas_id, params \\ []) do
    defaults = [
      id: UUID.gen(),
      name: "stage-1",
      conditions: [],
      connections: [],
      run_template: %InternalApi.Delivery.RunTemplate{
        type: InternalApi.Delivery.RunTemplate.Type.value(:TYPE_SEMAPHORE),
        semaphore: %InternalApi.Delivery.SemaphoreRunTemplate{
          project_id: UUID.gen(),
          branch: "main",
          pipeline_file: ".semaphore/semaphore.yml",
          parameters: %{
            "PARAM_1" => "VALUE_1",
            "PARAM_2" => "VALUE_2"
          }
        }
      }
    ]

    params = defaults |> Keyword.merge(params)

    DB.insert(:stages, %{
      id: params[:id],
      name: params[:name],
      org_id: org.id,
      canvas_id: canvas_id,
      api_model: %InternalApi.Delivery.Stage{
        id: params[:id],
        name: params[:name],
        organization_id: org.id,
        canvas_id: canvas_id,
        created_at: %Google.Protobuf.Timestamp{seconds: 1_549_885_252},
        conditions: params[:conditions],
        run_template: params[:run_template],
        connections: params[:connections]
      }
    })
  end

  def create_source(org, canvas_id, params \\ []) do
    defaults = [
      id: UUID.gen()
    ]

    params = defaults |> Keyword.merge(params)

    DB.insert(:sources, %{
      id: params[:id],
      name: params[:name],
      org_id: org.id,
      canvas_id: canvas_id
    })
  end

  def create_stage_event(org, canvas_id, stage_id, source_id, params \\ []) do
    defaults = [
      id: UUID.gen(),
      state: :STATE_PENDING,
      state_reason: :STATE_REASON_UNKNOWN,
      source_type: :TYPE_EVENT_SOURCE
    ]

    params = defaults |> Keyword.merge(params)

    DB.insert(:stage_events, %{
      id: params[:id],
      state: params[:state],
      state_reason: params[:state_reason],
      org_id: org.id,
      stage_id: stage_id,
      canvas_id: canvas_id,
      source_id: source_id,
      source_type: params[:source_type],
      approvals: []
    })
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(CanvasMock, :create_canvas, &__MODULE__.create_canvas/2)
      GrpcMock.stub(CanvasMock, :create_event_source, &__MODULE__.create_event_source/2)
      GrpcMock.stub(CanvasMock, :create_stage, &__MODULE__.create_stage/2)
      GrpcMock.stub(CanvasMock, :update_stage, &__MODULE__.update_stage/2)
      GrpcMock.stub(CanvasMock, :describe_canvas, &__MODULE__.describe_canvas/2)
      GrpcMock.stub(CanvasMock, :describe_event_source, &__MODULE__.describe_event_source/2)
      GrpcMock.stub(CanvasMock, :describe_stage, &__MODULE__.describe_stage/2)
      GrpcMock.stub(CanvasMock, :list_stages, &__MODULE__.list_stages/2)
      GrpcMock.stub(CanvasMock, :list_event_sources, &__MODULE__.list_event_sources/2)
      GrpcMock.stub(CanvasMock, :list_stage_events, &__MODULE__.list_stage_events/2)
      GrpcMock.stub(CanvasMock, :approve_stage_event, &__MODULE__.approve_stage_event/2)
    end

    def describe_canvas(req, _call) do
      case find_canvas(req) do
        {:ok, canvas} ->
          %InternalApi.Delivery.DescribeCanvasResponse{
            canvas: %InternalApi.Delivery.Canvas{
              id: canvas.id,
              name: canvas.name,
              organization_id: canvas.org_id,
              created_at: %Google.Protobuf.Timestamp{seconds: 1_549_885_252}
            }
          }

        {:error, message} ->
          raise GRPC.RPCError, status: :not_found, message: message
      end
    end

    def describe_event_source(req, _call) do
      case find_source(req) do
        {:ok, source} ->
          %InternalApi.Delivery.DescribeEventSourceResponse{
            event_source: %InternalApi.Delivery.EventSource{
              id: source.id,
              name: source.name,
              canvas_id: source.canvas_id,
              organization_id: source.org_id,
              created_at: %Google.Protobuf.Timestamp{seconds: 1_549_885_252}
            }
          }

        {:error, message} ->
          raise GRPC.RPCError, status: :not_found, message: message
      end
    end

    def list_event_sources(req, _call) do
      sources =
        DB.filter(:sources, org_id: req.organization_id, canvas_id: req.canvas_id)
        |> Enum.map(fn source ->
          %InternalApi.Delivery.EventSource{
            id: source.id,
            name: source.name,
            canvas_id: source.canvas_id,
            organization_id: source.org_id,
            created_at: %Google.Protobuf.Timestamp{seconds: 1_549_885_252}
          }
        end)

      %InternalApi.Delivery.ListEventSourcesResponse{event_sources: sources}
    end

    def list_stage_events(req, _call) do
      events =
        DB.filter(:stage_events,
          stage_id: req.stage_id,
          org_id: req.organization_id,
          canvas_id: req.canvas_id
        )
        |> Enum.map(fn event ->
          %InternalApi.Delivery.StageEvent{
            id: event.id,
            source_id: event.source_id,
            source_type: InternalApi.Delivery.Connection.Type.value(event.source_type),
            state: InternalApi.Delivery.StageEvent.State.value(event.state),
            created_at: %Google.Protobuf.Timestamp{seconds: 1_549_885_252}
          }
        end)

      %InternalApi.Delivery.ListStageEventsResponse{events: events}
    end

    def approve_stage_event(req, _call) do
      DB.filter(:stage_events,
        id: req.event_id,
        stage_id: req.stage_id,
        org_id: req.organization_id,
        canvas_id: req.canvas_id
      )
      |> case do
        [] ->
          raise GRPC.RPCError, status: :not_found, message: "Stage event not found"

        [event] ->
          approvals =
            event.approvals ++
              [
                %InternalApi.Delivery.StageEventApproval{
                  approved_at: %Google.Protobuf.Timestamp{seconds: 1_549_885_252},
                  approved_by: req.requester_id
                }
              ]

          DB.update(
            :stage_events,
            %{event | approvals: approvals},
            id: event.id
          )

          %InternalApi.Delivery.ApproveStageEventResponse{
            event: %InternalApi.Delivery.StageEvent{
              id: event.id,
              source_id: event.source_id,
              source_type: InternalApi.Delivery.Connection.Type.value(event.source_type),
              state: InternalApi.Delivery.StageEvent.State.value(event.state),
              state_reason: InternalApi.Delivery.StageEvent.StateReason.value(event.state_reason),
              created_at: %Google.Protobuf.Timestamp{seconds: 1_549_885_252},
              approvals: approvals
            }
          }
      end
    end

    def list_stages(req, _call) do
      stages =
        DB.filter(:stages, org_id: req.organization_id, canvas_id: req.canvas_id)
        |> Enum.map(fn stage ->
          %InternalApi.Delivery.Stage{
            id: stage.id,
            name: stage.name,
            canvas_id: stage.canvas_id,
            organization_id: stage.org_id,
            created_at: %Google.Protobuf.Timestamp{seconds: 1_549_885_252}
          }
        end)

      %InternalApi.Delivery.ListStagesResponse{stages: stages}
    end

    def describe_stage(req, _call) do
      case find_stage(req) do
        {:ok, stage} ->
          %InternalApi.Delivery.DescribeStageResponse{
            stage: %InternalApi.Delivery.Stage{
              id: stage.id,
              name: stage.name,
              canvas_id: stage.canvas_id,
              organization_id: stage.org_id,
              created_at: %Google.Protobuf.Timestamp{seconds: 1_549_885_252},
              conditions: stage.api_model.conditions,
              run_template: stage.api_model.run_template,
              connections: stage.api_model.connections
            }
          }

        {:error, message} ->
          raise GRPC.RPCError, status: :not_found, message: message
      end
    end

    def create_stage(req, _call) do
      id = UUID.gen()
      org_id = req.organization_id
      canvas_id = req.canvas_id

      DB.filter(:stages, org_id: req.organization_id, canvas_id: req.canvas_id, name: req.name)
      |> case do
        [] ->
          stage = %InternalApi.Delivery.Stage{
            id: id,
            name: req.name,
            organization_id: org_id,
            canvas_id: canvas_id,
            created_at: %Google.Protobuf.Timestamp{seconds: 1_549_885_252},
            conditions: req.conditions,
            connections: req.connections,
            run_template: req.run_template
          }

          DB.insert(:stages, %{
            id: id,
            name: req.name,
            org_id: org_id,
            canvas_id: canvas_id,
            api_model: stage
          })

          %InternalApi.Delivery.CreateStageResponse{
            stage: stage
          }

        _ ->
          raise GRPC.RPCError,
            status: :already_exists,
            message: "Stage #{req.name} already exists"
      end
    end

    def update_stage(req, _call) do
      case find_stage(req) do
        {:ok, stage} ->
          %InternalApi.Delivery.UpdateStageResponse{
            stage: %InternalApi.Delivery.Stage{
              id: stage.id,
              name: stage.name,
              organization_id: stage.org_id,
              canvas_id: stage.canvas_id,
              conditions: stage.api_model.conditions,
              connections: stage.api_model.connections,
              run_template: stage.api_model.run_template,
              created_at: stage.api_model.created_at
            }
          }

        {:error, message} ->
          raise GRPC.RPCError, status: :not_found, message: message
      end
    end

    def create_event_source(req, _call) do
      id = UUID.gen()
      org_id = req.organization_id
      canvas_id = req.canvas_id

      DB.filter(:sources, org_id: req.organization_id, canvas_id: req.canvas_id, name: req.name)
      |> case do
        [] ->
          DB.insert(:sources, %{
            id: id,
            name: req.name,
            org_id: org_id,
            canvas_id: canvas_id
          })

          %InternalApi.Delivery.CreateEventSourceResponse{
            event_source: %InternalApi.Delivery.EventSource{
              id: id,
              name: req.name,
              organization_id: org_id,
              canvas_id: canvas_id,
              created_at: %Google.Protobuf.Timestamp{seconds: 1_549_885_252}
            }
          }

        _ ->
          raise GRPC.RPCError,
            status: :already_exists,
            message: "Canvas #{req.name} already exists"
      end
    end

    def create_canvas(req, _call) do
      org_id = req.organization_id
      id = UUID.gen()

      case find_canvas(%{organization_id: org_id, name: req.name}) do
        {:ok, _} ->
          raise GRPC.RPCError,
            status: :already_exists,
            message: "Canvas #{req.name} already exists"

        _ ->
          DB.insert(:canvases, %{
            id: id,
            name: req.name,
            org_id: org_id
          })

          %InternalApi.Delivery.CreateCanvasResponse{
            canvas: %InternalApi.Delivery.Canvas{
              id: id,
              name: req.name,
              organization_id: org_id,
              created_at: %Google.Protobuf.Timestamp{seconds: 1_549_885_252}
            }
          }
      end
    end

    defp find_canvas(req) do
      case Enum.find(org_canvases(req.organization_id), fn c ->
             c.id == req.id || c.name == req.name
           end) do
        nil ->
          {:error, "Canvas not found"}

        canvas ->
          {:ok, canvas}
      end
    end

    defp find_source(req) do
      DB.filter(:sources, org_id: req.organization_id, canvas_id: req.canvas_id)
      |> Enum.find(fn c -> c.id == req.id || c.name == req.name end)
      |> case do
        nil ->
          {:error, "Source not found"}

        source ->
          {:ok, source}
      end
    end

    defp find_stage(%InternalApi.Delivery.UpdateStageRequest{id: id}) do
      DB.filter(:stages, id: id)
      |> Enum.find(fn c -> c.id == id end)
      |> case do
        nil ->
          {:error, "Stage not found"}

        stage ->
          {:ok, stage}
      end
    end

    defp find_stage(req) do
      DB.filter(:stages, org_id: req.organization_id, canvas_id: req.canvas_id)
      |> Enum.find(fn c -> c.id == req.id || c.name == req.name end)
      |> case do
        nil ->
          {:error, "Stage not found"}

        stage ->
          {:ok, stage}
      end
    end

    defp org_canvases(org_id) do
      DB.filter(:canvases, org_id: org_id)
    end
  end
end
