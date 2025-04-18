defmodule PublicAPI.Handlers.EventSources.Formatter do
  @moduledoc false
  alias InternalApi.Delivery, as: API

  require Logger

  def describe(source = %API.EventSource{}, ctx) do
    {:ok, source_from_pb(source, ctx)}
  end

  def list(%API.ListEventSourcesResponse{event_sources: sources}, ctx) do
    {:ok, %{
      next_page_token: nil,
      page_size: 100,
      entries: Enum.map(sources, fn source -> source_from_pb(source, ctx) end)
    }}
  end

  defp source_from_pb(%API.EventSource{} = source, ctx) do
    organization = %{id: source.organization_id, name: ctx.organization.name}
    canvas = %{id: source.canvas_id}

    %{
      apiVersion: "v2",
      kind: "EventSource",
      metadata: %{
        id: source.id,
        name: source.name,
        organization: organization,
        canvas: canvas,
        timeline: %{
          created_at: PublicAPI.Util.Timestamps.to_timestamp(source.created_at),
          created_by: nil
        }
      },
      spec: %{}
    }
  end
end
