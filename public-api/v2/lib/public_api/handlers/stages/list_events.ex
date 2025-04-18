defmodule PublicAPI.Handlers.Stages.List do
  @moduledoc false
  require Logger

  alias InternalClients.Canvases, as: CanvasesClient
  alias PublicAPI.Schemas

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  # TODO: put API behind feature flag
  # plug(PublicAPI.Plugs.FeatureFlag, feature: "canvas")

  @operation_id "Stages.ListEvents"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Stages.ListEventsResponse

  plug(PublicAPI.Plugs.CanvasIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  # TODO: use proper permission here
  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.dashboards.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["list", "stage_events"])
  plug(:list_events)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["StageEvents"],
      summary: "List events in the stage queue",
      description: "List events in the stage queue.",
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
        )
      ],
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "List of stage events",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def list_events(conn, _opts) do
    Map.merge(conn.params, %{
      id: conn.assigns[:id],
      organization_id: conn.assigns[:organization_id],
      canvas_id: conn.assigns[:canvas_id]
    })
    |> CanvasesClient.list_stage_events()
    |> case do
      {:ok, response} ->
        response
        |> PublicAPI.Handlers.Stages.Formatter.list_events()
        |> set_response(conn)

      err ->
        Logger.error("Error listing stages: #{inspect(err)}")

        err
        |> set_response(conn)
    end
  end
end
