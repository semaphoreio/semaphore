defmodule PublicAPI.Handlers.EventSources.Formatter do
  @moduledoc false
  alias InternalApi.Delivery, as: API

  def describe(ctx, source = %API.EventSource{}, key \\ nil) do
    {:ok, source_from_pb(ctx, source, key)}
  end

  def list(sources, ctx) do
    {:ok,
     %{
       next_page_token: nil,
       page_size: 100,
       entries: Enum.map(sources, fn source -> source_from_pb(ctx, source, nil) end)
     }}
  end

  defp source_from_pb(ctx, source = %API.EventSource{}, key) do
    %{
      apiVersion: "v2",
      kind: "EventSource",
      metadata: %{
        id: source.id,
        name: source.name,
        organization: %{
          id: source.organization_id,
          name: ctx.organization.name
        },
        canvas: %{
          id: source.canvas_id
        },
        timeline: %{
          created_at: PublicAPI.Util.Timestamps.to_timestamp(source.created_at),
          created_by: nil
        },
        status: status(key)
      },
      spec: %{}
    }
  end

  defp status(nil), do: nil
  defp status(key), do: %{key: key}
end
