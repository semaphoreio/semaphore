defmodule Support.Stubs.Delivery do
  # Use the DB stub for in-memory storage
  alias Support.Stubs.DB

  def init do
    DB.add_table(:canvas, [:id, :api_model])
    DB.add_table(:stage, [:id, :api_model])
    DB.add_table(:stage_events, [:id, :stage_id, :api_model])
    DB.add_table(:event_source, [:id, :api_model])
  end

  defmodule Grpc do
    use GRPC.Server, service: InternalApi.Delivery.Delivery.Service

    # --- Delivery API RPCs ---
    def create_canvas(%InternalApi.Delivery.CreateCanvasRequest{} = req, _stream) do
      canvas = %InternalApi.Delivery.Canvas{
        id: Ecto.UUID.generate(),
        name: req.name,
        organization_id: req.organization_id,
        created_by: req.requester_id,
        created_at: %Google.Protobuf.Timestamp{seconds: :os.system_time(:second), nanos: 0}
      }

      put(:canvas, canvas)
      %InternalApi.Delivery.CreateCanvasResponse{canvas: canvas}
    end

    def describe_canvas(%InternalApi.Delivery.DescribeCanvasRequest{id: id}, _stream) do
      case get(:canvas, id) do
        nil -> raise GRPC.RPCError, status: :not_found, message: "Canvas not found"
        canvas -> %InternalApi.Delivery.DescribeCanvasResponse{canvas: canvas}
      end
    end

    def list_stages(%InternalApi.Delivery.ListStagesRequest{}, _stream) do
      # Just return all stages for now
      stages = list(:stage)
      %InternalApi.Delivery.ListStagesResponse{stages: stages}
    end

    def create_stage(%InternalApi.Delivery.CreateStageRequest{} = req, _stream) do
      stage = %InternalApi.Delivery.Stage{
        id: Ecto.UUID.generate(),
        name: req.name,
        organization_id: req.organization_id,
        canvas_id: req.canvas_id,
        created_at: %Google.Protobuf.Timestamp{seconds: :os.system_time(:second), nanos: 0},
        connections: req.connections,
        conditions: req.conditions,
        run_template: req.run_template
      }

      put(:stage, stage)
      %InternalApi.Delivery.CreateStageResponse{stage: stage}
    end

    def describe_stage(%InternalApi.Delivery.DescribeStageRequest{id: id}, _stream) do
      case get(:stage, id) do
        nil -> raise GRPC.RPCError, status: :not_found, message: "Stage not found"
        stage -> %InternalApi.Delivery.DescribeStageResponse{stage: stage}
      end
    end

    def list_event_sources(
          %InternalApi.Delivery.ListEventSourcesRequest{canvas_id: _canvas_id},
          _stream
        ) do
      sources = list(:event_source)
      %InternalApi.Delivery.ListEventSourcesResponse{event_sources: sources}
    end

    def create_event_source(%InternalApi.Delivery.CreateEventSourceRequest{} = req, _stream) do
      ev = %InternalApi.Delivery.EventSource{
        id: Ecto.UUID.generate(),
        name: req.name,
        organization_id: req.organization_id,
        canvas_id: req.canvas_id,
        created_at: %Google.Protobuf.Timestamp{seconds: :os.system_time(:second), nanos: 0}
      }

      put(:event_source, ev)
      %InternalApi.Delivery.CreateEventSourceResponse{event_source: ev, key: Ecto.UUID.generate()}
    end

    def describe_event_source(
          %InternalApi.Delivery.DescribeEventSourceRequest{id: id},
          _stream
        ) do
      case get(:event_source, id) do
        nil -> raise GRPC.RPCError, status: :not_found, message: "EventSource not found"
        ev -> %InternalApi.Delivery.DescribeEventSourceResponse{event_source: ev}
      end
    end

    def update_stage(%InternalApi.Delivery.UpdateStageRequest{} = req, _stream) do
      case get(:stage, req.id) do
        nil ->
          raise GRPC.RPCError, status: :not_found, message: "Stage not found"

        stage ->
          stage = %InternalApi.Delivery.Stage{
            id: req.id,
            name: stage.name,
            organization_id: stage.organization_id,
            canvas_id: stage.canvas_id,
            created_at: stage.created_at,
            connections: req.connections || stage.connections,
            conditions: stage.conditions,
            run_template: stage.run_template
          }

          DB.upsert(:stage, %{id: stage.id, api_model: stage})
          %InternalApi.Delivery.UpdateStageResponse{stage: stage}
      end
    end

    def list_stage_events(%InternalApi.Delivery.ListStageEventsRequest{} = req, _stream) do
      case DB.find_all_by(:stage_events, :stage_id, req.stage_id) do
        nil -> %InternalApi.Delivery.ListStageEventsResponse{events: []}
        events -> %InternalApi.Delivery.ListStageEventsResponse{events: Enum.map(events, & &1.api_model)}
      end
    end

    def approve_stage_event(%InternalApi.Delivery.ApproveStageEventRequest{} = req, _stream) do
      case DB.find_by(:stage_events, :id, req.event_id) do
        nil -> raise GRPC.RPCError, status: :not_found, message: "Stage event not found"
        event ->
          # update event state from STATE_WAITING to STATE_PENDING for event
          updated_event = %InternalApi.Delivery.StageEvent{
            id: event.id,
            state: :STATE_PENDING,
            created_at: event.api_model.created_at,
            approvals: [%InternalApi.Delivery.StageEventApproval{
              approved_by: "user-#{req.requester_id}@example.com",
              approved_at: %Google.Protobuf.Timestamp{seconds: :os.system_time(:second), nanos: 0}
            }]
          }

          DB.upsert(:stage_events, %{id: event.id, stage_id: event.stage_id, api_model: updated_event})
          %InternalApi.Delivery.ApproveStageEventResponse{event: updated_event}
      end
    end

    # All other RPCs: not implemented
    def unimplemented(_req, _stream) do
      raise GRPC.RPCError, status: :unimplemented, message: "Unimplemented"
    end

    for {rpc, _, _} <- InternalApi.Delivery.Delivery.Service.__rpc_calls__() do
      unless Module.defines?(__MODULE__, {String.downcase(to_string(rpc)), 2}) do
        def unquote(String.downcase(to_string(rpc)))(req, stream), do: unimplemented(req, stream)
      end
    end

    # --- In-memory storage helpers ---
    defp put(type, value) do
      # Store only id and api_model in the DB stub
      id = Map.get(value, :id) || (is_struct(value) && Map.get(Map.from_struct(value), :id))
      api_model = value
      DB.insert(type, %{id: id, api_model: api_model})
    end

    defp get(type, id) do
      # Retrieve the api_model for the given id
      case DB.find(type, id) do
        nil -> nil
        %{api_model: model} -> model
      end
    end

    defp list(type) do
      # Return only the api_model field for all entries
      DB.all(type)
      |> Enum.map(& &1.api_model)
    end
  end

  # --- Testing Helpers ---
  @doc "Clears all mock data from the stub store"
  def clear_mock_data do
    DB.clear(:canvas)
    DB.clear(:stage)
    DB.clear(:event_source)
  end

  @doc "Seeds a canvas into the mock store"
  def seed_canvas(attrs \\ %{}) do
    id = attrs[:id] || Ecto.UUID.generate()
    now = %Google.Protobuf.Timestamp{seconds: :os.system_time(:second), nanos: 0}

    canvas = %InternalApi.Delivery.Canvas{
      id: id,
      name: attrs[:name] || "canvas-#{id}",
      organization_id: attrs[:organization_id] || "org-#{id}",
      created_by: attrs[:created_by] || "user-#{id}",
      created_at: attrs[:created_at] || now
    }

    put(:canvas, canvas)
    Map.from_struct(canvas)
  end

  @doc """
  Seeds a stage with the given attributes.
  """
  def seed_stage(attrs \\ %{}) do
    id = attrs[:id] || Ecto.UUID.generate()
    now = %Google.Protobuf.Timestamp{seconds: :os.system_time(:second), nanos: 0}

    stage = %InternalApi.Delivery.Stage{
      id: id,
      name: attrs[:name] || "stage-#{id}",
      organization_id: attrs[:organization_id] || "org-#{id}",
      canvas_id: attrs[:canvas_id] || id,
      created_at: attrs[:created_at] || now,
      connections: attrs[:connections] || [],
      conditions: attrs[:conditions] || [],
      run_template:
        attrs[:run_template] ||
          %{
            type: :TYPE_SEMAPHORE,
            semaphore: %{
              project_id: UUID.uuid4(),
              branch: "main",
              pipeline_fle: ".semaphore/semaphore.yml",
              task_id: UUID.uuid4()
            }
          }
    }

    put(:stage, stage)
    stage
  end

  @doc """
  Updates an existing stage with new attributes.
  Only updates the fields specified in attrs, preserving other fields.
  """
  def update_stage(attrs) do
    case get(:stage, attrs[:id]) do
      nil ->
        {:error, "Stage not found"}

      existing_stage ->
        # Merge the attributes with the existing stage
        updated_stage =
          Enum.reduce(attrs, existing_stage, fn {k, v}, acc ->
            Map.put(acc, k, v)
          end)

        # Properly structure the record for DB.upsert
        record = %{id: updated_stage.id, api_model: updated_stage}
        DB.upsert(:stage, record)
        updated_stage
    end
  end

  def update_canvas(attrs) do
    case get(:canvas, attrs[:id]) do
      nil ->
        {:error, "Canvas not found"}

      existing_canvas ->
        # Merge the attributes with the existing canvas
        updated_canvas =
          Enum.reduce(attrs, existing_canvas.api_model, fn {k, v}, acc ->
            Map.put(acc, k, v)
          end)

        # Properly structure the record for DB.upsert
        record = %{id: updated_canvas.id, api_model: updated_canvas}
        DB.upsert(:canvas, record)
        updated_canvas
    end
  end

  def delete_stage(id) do
    DB.delete(:stage, id)
  end

  def list_canvases do
    list(:canvas)
    |> Enum.map(&Map.from_struct/1)
  end

  @doc "Lists stage events for a specific stage"
  def list_stage_events(%{stage_id: stage_id}) do
    events = DB.find_all_by(:stage_events, :stage_id, stage_id) |> Enum.map(& &1.api_model)
    %InternalApi.Delivery.ListStageEventsResponse{events: events}
  end

  @doc "Creates a stage event with the given attributes, using reasonable defaults"
  def seed_event_for_stage(attrs \\ %{}) do
    now = %Google.Protobuf.Timestamp{seconds: :os.system_time(:second), nanos: 0}

    # Create approvals if specified
    approvals = case attrs[:approval_count] do
      count when is_integer(count) and count > 0 ->
        Enum.map(1..count, fn i ->
          %InternalApi.Delivery.StageEventApproval{
            approved_by: "user-#{i}@example.com",
            approved_at: now
          }
        end)
      _ -> []
    end

    # Set up the stage event according to the protobuf definition
    event = %InternalApi.Delivery.StageEvent{
      id: attrs[:id] || UUID.uuid4(),
      source_id: attrs[:source_id] || UUID.uuid4(),
      source_type: attrs[:source_type] || :TYPE_EVENT_SOURCE,
      state: attrs[:state] || :STATE_PENDING,
      state_reason: attrs[:state_reason] || case attrs[:state] do
        :STATE_WAITING -> :STATE_REASON_APPROVAL
        _ -> :STATE_REASON_UNKNOWN
      end,
      created_at: attrs[:created_at] || now,
      approvals: attrs[:approvals] || approvals
    }

    # Store additional metadata for lookup
    stage_id = attrs[:stage_id]
    if stage_id do
      DB.insert(:stage_events, %{id: event.id, stage_id: stage_id, api_model: event})
    else
      raise "stage_id is required to create a stage event"
    end

    event
  end

  @doc "Seeds an event source into the mock store"
  def seed_event_source(attrs \\ %{}) do
    id = attrs[:id] || Ecto.UUID.generate()
    now = %Google.Protobuf.Timestamp{seconds: :os.system_time(:second), nanos: 0}

    ev = %InternalApi.Delivery.EventSource{
      id: id,
      name: attrs[:name] || "event_source-#{id}",
      organization_id: attrs[:organization_id] || "org-#{id}",
      canvas_id: attrs[:canvas_id] || id,
      created_at: attrs[:created_at] || now
    }

    put(:event_source, ev)
    ev
  end

  @doc "Seeds default mock data into the store"
  def seed_default_data(opts \\ []) do
    org_id = Keyword.get(opts, :org_id, Support.Stubs.Organization.default_org_id())
    user_id = Keyword.get(opts, :user_id, Support.Stubs.User.default_user_id())
    clear_mock_data()
    # Insert default mock entities here
    seed_canvas(%{
      id: "f9a84bcf-bd42-4335-a2c0-723f9761d4bf",
      name: "Test Canvas",
      organization_id: org_id,
      created_by: user_id
    })
    |> then(fn canvas ->
      event_source =
        seed_event_source(%{
          canvas_id: canvas.id,
          organization_id: org_id
        })

      %{canvas: canvas, event_source: event_source}
    end)
    |> then(fn %{canvas: canvas, event_source: event_source} ->
      first_stage =
        seed_stage(%{
          canvas_id: canvas.id,
          name: "Test Stage",
          connections: [
            %{
              type: :TYPE_EVENT_SOURCE,
              name: event_source.name,
              filters: [],
              filter_operator: :FILTER_OPERATOR_AND
            }
          ]
        })

      seed_event_for_stage(%{stage_id: first_stage.id})
      seed_event_for_stage(%{stage_id: first_stage.id, state: :STATE_PROCESSED})

      second_stage =
        seed_stage(%{
          canvas_id: canvas.id,
          name: "Second Test Stage",
          conditions: [
            %{
              type: :CONDITION_TYPE_APPROVAL,
              approval: %{count: 1}
            }
          ],
          connections: [
            %{
              type: :TYPE_EVENT_SOURCE,
              name: event_source.name,
              filters: [],
              filter_operator: :FILTER_OPERATOR_AND
            },
            %{
              type: :TYPE_STAGE,
              name: first_stage.name,
              filters: [],
              filter_operator: :FILTER_OPERATOR_AND
            }
          ]
        })

      seed_stage(%{
        canvas_id: canvas.id,
        name: "Third Test Stage",
        conditions: [
          %{
            type: :CONDITION_TYPE_TIME_WINDOW,
            time_window: %{
              start: "09:00",
              end: "17:00",
              week_days: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
            }
          }
        ],
        connections: [
          %{
            type: :TYPE_EVENT_SOURCE,
            name: event_source.name,
            filters: [],
            filter_operator: :FILTER_OPERATOR_AND
          },
          %{
            type: :TYPE_STAGE,
            name: second_stage.name,
            filters: [],
            filter_operator: :FILTER_OPERATOR_AND
          }
        ]
      })
    end)
  end

  def delete_event_source(id) do
    DB.delete(:event_source, id)
  end

  def update_event_source(attrs) do
    case get(:event_source, attrs[:id]) do
      nil ->
        {:error, "Event source not found"}

      existing_event_source ->
        # Merge the attributes with the existing event source
        updated_event_source =
          Enum.reduce(attrs, existing_event_source, fn {k, v}, acc ->
            Map.put(acc, k, v)
          end)

        # Update the event source
        DB.upsert(:event_source, %{id: updated_event_source.id, api_model: updated_event_source})
        {:ok, updated_event_source}
    end
  end

  # --- In-memory storage helpers ---
  defp put(type, value) do
    # Store only id and api_model in the DB stub
    id = Map.get(value, :id) || (is_struct(value) && Map.get(Map.from_struct(value), :id))
    api_model = value
    DB.insert(type, %{id: id, api_model: api_model})
  end

  defp get(type, id) do
    # Retrieve the api_model for the given id
    case DB.find(type, id) do
      nil -> nil
      %{api_model: model} -> model
    end
  end

  defp list(type) do
    # Return only the api_model field for all entries
    DB.all(type)
    |> Enum.map(& &1.api_model)
  end
end
