defmodule Scouter.GRPC.Server do
  @moduledoc """
  This module is responsible for defining the GRPC server for the Scouter service.
  """
  use GRPC.Server, service: InternalApi.Scouter.ScouterService.Service

  alias InternalApi.Scouter.{
    SignalRequest,
    SignalResponse,
    ListEventsRequest,
    ListEventsResponse
  }

  @spec signal(SignalRequest.t(), GRPC.Server.Stream.t()) :: SignalResponse.t()
  def signal(req, _stream) do
    Scouter.Storage.EventQueries.create(req.context, req.event_id)
    |> case do
      {:ok, event} ->
        %SignalResponse{
          event: grpc_event(event)
        }

      {:error, errors} ->
        raise GRPC.RPCError,
          status: GRPC.Status.invalid_argument(),
          message: errors
    end
  end

  @spec list_events(ListEventsRequest.t(), GRPC.Server.Stream.t()) :: ListEventsResponse.t()
  def list_events(req, _stream) do
    events =
      Scouter.Storage.EventQueries.list(req.context, req.event_ids)

    %ListEventsResponse{
      events: Enum.map(events, &grpc_event/1)
    }
  end

  defp grpc_event(event) do
    %InternalApi.Scouter.Event{
      id: event.event_id,
      context: %InternalApi.Scouter.Context{
        organization_id: event.organization_id,
        project_id: event.project_id,
        user_id: event.user_id
      },
      occured_at: %Google.Protobuf.Timestamp{seconds: DateTime.to_unix(event.inserted_at)}
    }
  end
end
