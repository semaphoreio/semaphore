defmodule PublicAPI.Handlers.Stages.Describe do
  @moduledoc false
  require Logger

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

  @response_schema Schemas.Stages.Stage

  plug(PublicAPI.Plugs.CanvasIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  # TODO: use proper permission here
  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.dashboards.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["describe", "event_sources"])
  plug(PublicAPI.Handlers.Stages.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:describe)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Stages"],
      summary: "Describe a stage from a canvas",
      description: "Describe a stage from a canvas.",
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
              "Stage",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def describe(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    org_name = conn.assigns[:organization_username]

    ctx = %{
      organization: %{
        id: org_id,
        name: org_name
      }
    }

    conn
    |> get_resource()
    |> case do
      {:ok, source} ->
        source
        |> PublicAPI.Handlers.Stages.Formatter.describe(ctx)
        |> set_response(conn)

      {:error, _} = error ->
        error
        |> set_response(conn)
    end
  end
end
