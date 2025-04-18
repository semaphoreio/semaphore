defmodule Support.Stubs.Canvases do
  alias Support.Stubs.{DB, UUID}

  def init do
    DB.add_table(:canvases, [:id, :name, :org_id])
    DB.add_table(:stages, [:id, :name, :org_id, :canvas_id, :api_model])
    DB.add_table(:stage_events, [:id, :org_id, :canvas_id, :stage_id, :state, :approved_at])
    DB.add_table(:sources, [:id, :name, :org_id, :canvas_id])

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
      name: "stage-1"
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
        created_at: %Google.Protobuf.Timestamp{seconds: 1_549_885_252}
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

  def create_stage_event(org, canvas_id, stage_id, params \\ []) do
    defaults = [
      id: UUID.gen(),
      state: :pending
    ]

    params = defaults |> Keyword.merge(params)

    DB.insert(:stage_events, %{
      id: params[:id],
      state: params[:state],
      org_id: org.id,
      stage_id: stage_id,
      canvas_id: canvas_id,
      approved_at: nil
    })
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(CanvasMock, :create_canvas, &__MODULE__.create_canvas/2)
      GrpcMock.stub(CanvasMock, :describe_canvas, &__MODULE__.describe_canvas/2)
      GrpcMock.stub(CanvasMock, :describe_event_source, &__MODULE__.describe_event_source/2)
      GrpcMock.stub(CanvasMock, :describe_stage, &__MODULE__.describe_stage/2)
      GrpcMock.stub(CanvasMock, :list_stages, &__MODULE__.list_stages/2)
      GrpcMock.stub(CanvasMock, :list_event_sources, &__MODULE__.list_event_sources/2)
      GrpcMock.stub(CanvasMock, :list_stage_events, &__MODULE__.list_stage_events/2)
    end

    def describe_canvas(req, _call) do
      case find_canvas(req) do
        {:ok, canvas} ->
          %InternalApi.Delivery.DescribeCanvasResponse{
            canvas: %InternalApi.Delivery.Canvas{
              id: canvas.id,
              name: canvas.name,
              organization_id: canvas.org_id,
              created_at: %Google.Protobuf.Timestamp{seconds: canvas.created_at}
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
          org_id: req.org_id,
          canvas_id: req.canvas_id
        )
        |> Enum.map(fn event ->
          %InternalApi.Delivery.StageEvent{
            id: event.id,
            source_id: event.api_model.source_id,
            source_type: event.api_model.source_type,
            state: event.api_model.state,
            created_at: %Google.Protobuf.Timestamp{seconds: 1_549_885_252}
          }
        end)

      %InternalApi.Delivery.ListStageEventsResponse{events: events}
    end

    def approve_stage_event(req, _call) do
      DB.filter(:stage_events,
        id: req.id,
        stage_id: req.stage_id,
        org_id: req.organization_id,
        canvas_id: req.canvas_id
      )
      |> case do
        [] ->
          raise GRPC.RPCError, status: :not_found, message: "Stage event not found"

        [event] ->
          DB.update(
            :stage_events,
            %{
              id: event.id,
              org_id: event.org_id,
              canvas_id: event.canvas_id,
              stage_id: event.stage_id,
              api_model: Map.update(event.api_model, :approved_at, nil, DateTime.utc_now())
            },
            id: event.id
          )
      end
    end

    def list_stages(req, _call) do
      stages =
        DB.filter(:stages, org_id: req.org_id, canvas_id: req.canvas_id)
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
              created_at: %Google.Protobuf.Timestamp{seconds: 1_549_885_252}
            }
          }

        {:error, message} ->
          raise GRPC.RPCError, status: :not_found, message: message
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
            org_id: org_id,
            created_at: 1_549_885_252
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

    defp find_stage(req) do
      DB.filter(:stages, org_id: req.org_id, canvas_id: req.canvas_id)
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
