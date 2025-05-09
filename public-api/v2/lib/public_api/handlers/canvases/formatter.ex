defmodule PublicAPI.Handlers.Canvases.Formatter do
  @moduledoc false
  alias InternalApi.Delivery, as: API

  require Logger

  def describe(canvas = %API.Canvas{}, ctx) do
    {:ok, canvas_from_pb(canvas, ctx)}
  end

  defp canvas_from_pb(canvas = %API.Canvas{}, ctx) do
    organization = %{id: canvas.organization_id, name: ctx.organization.name}

    %{
      apiVersion: "v2",
      kind: "Canvas",
      metadata: %{
        id: canvas.id,
        name: canvas.name,
        organization: organization,
        timeline: %{
          created_at: PublicAPI.Util.Timestamps.to_timestamp(canvas.created_at),
          created_by: nil
        }
      },
      spec: %{}
    }
  end
end
