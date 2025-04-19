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

  @operation_id "Stages.List"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Stages.ListResponse

  plug(PublicAPI.Plugs.CanvasIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  # TODO: use proper permission here
  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.dashboards.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["list", "stages"])
  plug(:list)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Stages"],
      summary: "List stages for a canvas",
      description: "List stages for a canvas",
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
        )
      ],
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "List of stages",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def list(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    org_name = conn.assigns[:organization_username]

    ctx = %{
      organization: %{
        id: org_id,
        name: org_name
      }
    }

    Map.merge(conn.params, %{
      organization_id: conn.assigns[:organization_id]
    })
    |> CanvasesClient.list_stages()
    |> case do
      {:ok, stages} ->
        stages
        |> PublicAPI.Handlers.Stages.Formatter.list(ctx)
        |> set_response(conn)

      err ->
        Logger.error("Error listing stages: #{inspect(err)}")

        err
        |> set_response(conn)
    end
  end
end
