defmodule PublicAPI.Handlers.Stages.ApproveEvent do
  @moduledoc false
  require Logger

  alias InternalClients.Canvases, as: CanvasesClient
  alias PublicAPI.Schemas

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  # TODO: put API behind feature flag
  # plug(PublicAPI.Plugs.FeatureFlag, feature: "canvas")

  @operation_id "Stages.ApproveEvent"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Stages.StageEvent

  plug(PublicAPI.Plugs.CanvasIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  # TODO: use proper permission here
  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.dashboards.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["approve", "stage_events"])
  plug(:approve_event)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["StageEvents"],
      summary: "Approve stage event",
      description: "Approve stage event.",
      operationId: @operation_id,
      parameters: [
        Operation.parameter(
          :canvas_id_or_name,
          :path,
          %Schema{
            anyOf: [
              PublicAPI.Schemas.Common.ResourceId.schema(),
              PublicAPI.Schemas.Common.Name.schema()
            ]
          },
          "Id or name of the canvas",
          required: true
        ),
        Operation.parameter(
          :id_or_name,
          :path,
          %Schema{
            anyOf: [
              PublicAPI.Schemas.Common.ResourceId.schema(),
              PublicAPI.Schemas.Common.Name.schema()
            ]
          },
          "Id or name of the stage",
          required: true
        ),
        Operation.parameter(
          :event_id,
          :query,
          %Schema{
            anyOf: [
              PublicAPI.Schemas.Common.ResourceId.schema()
            ]
          },
          "Id of the stage event",
          required: true
        )
      ],
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Stage event that was approved",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def approve_event(conn, _opts) do
    Map.merge(conn.params, %{
      id: conn.params.event_id,
      stage_id: conn.params.id_or_name,
      organization_id: conn.assigns[:organization_id],
      user_id: conn.assigns[:user_id]
    })
    |> CanvasesClient.approve_stage_event()
    |> case do
      {:ok, event} ->
        event
        |> PublicAPI.Handlers.Stages.Formatter.event()
        |> set_response(conn)

      err ->
        Logger.error("Error approving stage event: #{inspect(err)}")

        err
        |> set_response(conn)
    end
  end
end
