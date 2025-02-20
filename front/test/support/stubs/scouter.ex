defmodule Support.Stubs.Scouter do
  alias InternalApi.Scouter, as: API
  alias Support.Stubs.DB

  require Logger

  def init do
    DB.add_table(:events, [:event_id, :context, :occured_at])

    __MODULE__.Grpc.init()
  end

  def add_event(event_id, context \\ %{}, occured_at \\ nil) do
    context = %API.Context{
      organization_id: Map.get(context, :organization_id, ""),
      user_id: Map.get(context, :user_id, ""),
      project_id: Map.get(context, :project_id, "")
    }

    occured_at =
      Google.Protobuf.Timestamp.new(%{
        seconds: Timex.to_unix(occured_at || Timex.now())
      })

    DB.insert(:events, %{
      event_id: event_id,
      context: context,
      occured_at: occured_at
    })
  end

  def clear do
    DB.clear(:events)
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(
        ScouterMock,
        :signal,
        &Grpc.signal/2
      )

      GrpcMock.stub(
        ScouterMock,
        :list_events,
        &Grpc.list_events/2
      )
    end

    def signal(req, _) do
      event =
        DB.insert(:events, %{
          event_id: req.event_id,
          context: req.context,
          occured_at:
            Google.Protobuf.Timestamp.new(%{
              seconds: Timex.to_unix(Timex.now())
            })
        })

      %API.SignalResponse{
        event: %API.Event{
          id: event.event_id,
          context: event.context,
          occured_at: event.occured_at
        }
      }
    end

    def list_events(req, _) do
      event_ids = req.event_ids

      events =
        DB.all(:events)
        |> Enum.filter(fn
          event when event_ids != [] ->
            event.event_id in event_ids

          _ ->
            true
        end)
        |> Enum.map(fn event ->
          %API.Event{
            id: event.event_id,
            context: event.context,
            occured_at: event.occured_at
          }
        end)

      %API.ListEventsResponse{
        events: events
      }
    end
  end
end
