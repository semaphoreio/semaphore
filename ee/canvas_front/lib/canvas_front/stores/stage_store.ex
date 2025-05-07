defmodule CanvasFront.Stores.Stage do
  @moduledoc """
  GRPC-backed store for canvas stages.
  Fetches and saves stages for a canvas using InternalApi.Delivery.Delivery.Stub.
  """

  alias InternalApi.Delivery.{
    Delivery,
    Delivery.Stub,
    ListStagesRequest,
    ListStagesResponse,
    UpdateStageRequest,
    UpdateStageResponse,
    CreateStageRequest,
    CreateStageResponse,
    Stage,
    DescribeStageRequest,
    DescribeStageResponse,
    ApproveStageEventRequest,
    ApproveStageEventResponse
  }

  # Helper to open a GRPC channel
  defp grpc_channel do
    GRPC.Stub.connect(Application.fetch_env!(:canvas_front, :delivery_grpc_endpoint))
  end

  def get(params) do
    id = Map.get(params, :id)
    name = Map.get(params, :name)
    organization_id = Map.get(params, :organization_id)
    canvas_id = Map.get(params, :canvas_id)

    req = %DescribeStageRequest{
      id: id,
      name: name,
      organization_id: organization_id,
      canvas_id: canvas_id
    }

    with {:ok, channel} <- grpc_channel(),
         {:ok, %DescribeStageResponse{stage: stage}} <- Stub.describe_stage(channel, req) do
      Map.from_struct(stage)
    else
      _ -> nil
    end
  end

  @doc "Get the stages for a given canvas_id. Returns [] if not found."
  def list(params \\ %{}) do
    org_id = Map.get(params, :organization_id)
    canvas_id = Map.get(params, :canvas_id)
    req = %ListStagesRequest{organization_id: org_id, canvas_id: canvas_id}

    with {:ok, channel} <- grpc_channel(),
         {:ok, %ListStagesResponse{stages: stages}} <- Stub.list_stages(channel, req) do
      Enum.map(stages, &stage_to_map/1)
    else
      _ -> []
    end
  end

  def create(params) do
    with {:ok, channel} <- grpc_channel() do
      req = %CreateStageRequest{
        name: Map.get(params, :name),
        organization_id: Map.get(params, :organization_id),
        canvas_id: Map.get(params, :canvas_id),
        connections: Map.get(params, :connections),
        conditions: Map.get(params, :conditions),
        requester_id: Map.get(params, :requester_id),
        run_template: Map.get(params, :run_template)
      }

      with {:ok, %CreateStageResponse{stage: stage}} <- Stub.create_stage(channel, req) do
        Map.from_struct(stage)
      else
        _ -> nil
      end
    else
      _ -> nil
    end
  end

  @doc "Set the stages for a given canvas_id."
  def update(params) do
    with {:ok, channel} <- grpc_channel() do
      req = %UpdateStageRequest{
        id: Map.get(params, :id),
        connections: Map.get(params, :connections),
        requester_id: Map.get(params, :requester_id)
      }

      # Ignore result, just update all
      case Stub.update_stage(channel, req) do
        {:ok, %{stage: stage}} -> {:ok, stage}
        res -> res
      end
    end
  end

  @doc "Delete all stages for a given canvas_id. (Not implemented in GRPC API)"
  def delete(_params), do: :not_implemented

  @doc "Approve an event in a stage."
  def approve_event(params) do
    with {:ok, channel} <- grpc_channel() do
      req = %ApproveStageEventRequest{
        stage_id: Map.get(params, :stage_id),
        organization_id: Map.get(params, :organization_id),
        canvas_id: Map.get(params, :canvas_id),
        event_id: Map.get(params, :event_id),
        requester_id: Map.get(params, :requester_id)
      }

      with {:ok, %ApproveStageEventResponse{}} <- Stub.approve_stage_event(channel, req) do
        :ok
      else
        _ -> :error
      end
    else
      _ -> :error
    end
  end

  # Helper: convert Stage protobuf struct to map
  defp stage_to_map(%Stage{} = stage) do
    stage
    |> Map.from_struct()
    |> Map.update(:connections, [], fn conns -> Enum.map(conns, &Map.from_struct/1) end)
    |> Map.update(:conditions, [], fn conditions -> Enum.map(conditions, &Map.from_struct/1) end)
  end
end
